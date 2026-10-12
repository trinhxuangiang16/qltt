require('dotenv').config();
const express = require('express');
const path = require('node:path');
const { sql, getPool } = require('./db');

const app = express();
const port = Number(process.env.PORT || 3001);

app.use(express.json({ limit: '32kb' }));

function sqlError(error) {
  return {
    number: error.number || (error.originalError && error.originalError.info && error.originalError.info.number) || null,
    message: error.originalError && error.originalError.message ? error.originalError.message : error.message,
    code: error.code || null,
  };
}

function reportError(res, error) {
  console.error('API error:', error.number || error.code || '', error.message);
  res.status(500).json({ ok: false, error: sqlError(error) });
}

const ROLE_PERMISSIONS = {
  customer: [
    'home',
    'sp4-search',
    'fn2-seats',
    'fn1-membership',
    'sp1-book',
    'report-ticket',
  ],
  ticketing: [
    'home',
    'sp4-search',
    'fn2-seats',
    'fn1-membership',
    'sp1-book',
    'tg1-cancel',
    'report-ticket',
  ],
  flightops: [
    'home',
    'sp4-search',
    'fn2-seats',
    'sp2-status',
    'sp5-crew',
    'aircraft-maintenance',
    'fn3-aircraft',
    'cs1-delay',
    'cs2-payroll',
    'report-manifest',
    'report-crew',
    'report-performance',
  ],
  admin: ['*'],
};

function getUserRole(req) {
  const raw = String(req.headers['x-user-role'] || 'customer').toLowerCase().trim();
  return ['customer', 'ticketing', 'flightops', 'admin'].includes(raw) ? raw : 'customer';
}

function hasPermission(role, workflowId) {
  if (role === 'admin') return true;
  const list = ROLE_PERMISSIONS[role] || [];
  return list.includes(workflowId);
}

function required(value, label) {
  if (value === undefined || value === null || String(value).trim() === '') {
    const error = new Error('Vui lòng nhập ' + label + '.');
    error.status = 400;
    throw error;
  }
  return String(value).trim();
}

function dateValue(value, label) {
  const text = required(value, label);
  const date = /^\d{4}-\d{2}-\d{2}$/.test(text) ? new Date(text + 'T00:00:00.000Z') : null;
  if (!date || Number.isNaN(date.valueOf()) || date.toISOString().slice(0, 10) !== text) {
    const error = new Error(label + ' phải có dạng YYYY-MM-DD.');
    error.status = 400;
    throw error;
  }
  return text;
}

function utcDateTime(value, label) {
  const text = required(value, label);
  if (!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2})?$/.test(text)) {
    const error = new Error(label + ' cần có dạng YYYY-MM-DDTHH:mm[:ss] theo UTC.');
    error.status = 400;
    throw error;
  }
  const normalized = text.length === 16 ? text + ':00' : text;
  const date = new Date(normalized + 'Z');
  if (Number.isNaN(date.valueOf()) || date.toISOString().slice(0, 19) !== normalized) {
    const error = new Error(label + ' không phải ngày giờ UTC hợp lệ.');
    error.status = 400;
    throw error;
  }
  return normalized;
}

function stringParam(request, name, type, value) {
  request.input(name, type, value);
  return request;
}

async function query(pool, text, inputs = []) {
  const request = pool.request();
  for (const [name, type, value] of inputs) request.input(name, type, value);
  const result = await request.query(text);
  return result.recordset || [];
}

async function getOptions(pool) {
  const [airports, flights, passengers, employees, aircraft, tickets, tg2Flights, scheduledAircraft] = await Promise.all([
    query(pool, 'SELECT MaSanBay, TenSanBay, ThanhPho FROM dbo.SANBAY ORDER BY MaSanBay'),
    query(pool, `SELECT cb.MaChuyenBay, cb.MaMayBay, cb.GioKhoiHanhDK, cb.GioHaCanhDK, cb.TrangThai,
        cb.SoGheTrong, cb.GiaVePhoThong, cb.GiaVeThuongGia, db.MaSanBayDi, db.MaSanBayDen,
        s1.TenSanBay AS SanBayDi, s2.TenSanBay AS SanBayDen
      FROM dbo.CHUYENBAY cb JOIN dbo.DUONGBAY db ON db.MaDuongBay=cb.MaDuongBay
      JOIN dbo.SANBAY s1 ON s1.MaSanBay=db.MaSanBayDi JOIN dbo.SANBAY s2 ON s2.MaSanBay=db.MaSanBayDen
      ORDER BY cb.GioKhoiHanhDK`),
    query(pool, 'SELECT MaHanhKhach, HoTen FROM dbo.HANHKHACH ORDER BY MaHanhKhach'),
    query(pool, `SELECT MaNV, HoTen, ChucVu, TrangThai FROM dbo.NHANVIEN
      WHERE TrangThai=N'Đang làm việc'
        AND ChucVu IN (N'Cơ trưởng',N'Cơ phó',N'Tiếp viên trưởng',N'Tiếp viên hàng không') ORDER BY MaNV`),
    query(pool, 'SELECT MaMayBay, SoHieu, LoaiMayBay, SoGhe, TrangThai FROM dbo.MAYBAY ORDER BY MaMayBay'),
    query(pool, `SELECT MaVe, MaChuyenBay, MaHanhKhach, SoGhe, HangGhe, TrangThaiVe
      FROM dbo.VEBAY ORDER BY MaVe`),
    query(pool, `SELECT cb.MaChuyenBay,db.MaSanBayDi,db.MaSanBayDen,cb.GioKhoiHanhDK,cb.TrangThai
      FROM dbo.CHUYENBAY cb JOIN dbo.DUONGBAY db ON db.MaDuongBay=cb.MaDuongBay
      WHERE cb.GioKhoiHanhDK>SYSUTCDATETIME() AND cb.GioKhoiHanhDK<DATEADD(HOUR,24,SYSUTCDATETIME())
        AND cb.TrangThai<>N'Đã hủy' ORDER BY cb.GioKhoiHanhDK`),
    query(pool, `SELECT DISTINCT mb.MaMayBay,mb.SoHieu,mb.LoaiMayBay
      FROM dbo.MAYBAY mb JOIN dbo.CHUYENBAY cb ON cb.MaMayBay=mb.MaMayBay
      WHERE cb.GioKhoiHanhDK>SYSUTCDATETIME() AND cb.TrangThai<>N'Đã hủy' ORDER BY mb.MaMayBay`),
  ]);
  return { airports, flights, passengers, employees, aircraft, tickets, tg2Flights, scheduledAircraft };
}

app.get('/api/health', async (_req, res) => {
  try {
    const pool = await getPool();
    const result = await pool.request().query('SELECT DB_NAME() AS databaseName, SYSUTCDATETIME() AS utcNow');
    res.json({ ok: true, ...result.recordset[0] });
  } catch (error) {
    reportError(res, error);
  }
});

app.get('/api/auth/roles', (_req, res) => {
  res.json({
    roles: [
      { id: 'admin', label: 'Quản trị viên', badge: 'QT', desc: 'Toàn quyền hệ thống & Báo cáo' },
      { id: 'flightops', label: 'Điều phối viên', badge: 'ĐP', desc: 'Điều phối bay & Tổ bay' },
      { id: 'ticketing', label: 'Nhân viên bán vé', badge: 'BV', desc: 'Bán vé & Hoàn vé' },
      { id: 'customer', label: 'Khách hàng', badge: 'KH', desc: 'Tra cứu & Đặt vé cá nhân' },
    ],
    permissions: ROLE_PERMISSIONS,
  });
});

app.get('/api/options', async (req, res) => {
  try {
    const role = getUserRole(req);
    const pool = await getPool();
    const options = await getOptions(pool);

    // Nếu là Customer: Chỉ xem danh mục công khai (sân bay, chuyến, vé cơ bản), ẩn thông tin nhân sự/nội bộ
    if (role === 'customer') {
      return res.json({
        airports: options.airports,
        flights: options.flights,
        passengers: options.passengers,
        tickets: options.tickets,
        employees: [],
        aircraft: [],
        tg2Flights: [],
        scheduledAircraft: [],
      });
    }

    res.json(options);
  } catch (error) {
    reportError(res, error);
  }
});

app.get('/api/dashboard', async (req, res) => {
  try {
    const role = getUserRole(req);
    const pool = await getPool();
    const [counts, flights, mix] = await Promise.all([
      query(pool, `SELECT (SELECT COUNT(*) FROM dbo.CHUYENBAY) AS ChuyenBay,
        (SELECT COUNT(*) FROM dbo.VEBAY) AS VeBay, (SELECT COUNT(*) FROM dbo.HANHKHACH) AS HanhKhach,
        (SELECT COUNT(*) FROM dbo.MAYBAY) AS MayBay`),
      query(pool, `SELECT TOP (8) cb.MaChuyenBay, s1.MaSanBay AS SanBayDi, s2.MaSanBay AS SanBayDen,
        cb.GioKhoiHanhDK, cb.TrangThai, cb.SoGheTrong, cb.MaMayBay
        FROM dbo.CHUYENBAY cb JOIN dbo.DUONGBAY db ON db.MaDuongBay=cb.MaDuongBay
        JOIN dbo.SANBAY s1 ON s1.MaSanBay=db.MaSanBayDi JOIN dbo.SANBAY s2 ON s2.MaSanBay=db.MaSanBayDen
        ORDER BY cb.GioKhoiHanhDK`),
      query(pool, `SELECT TrangThai, COUNT(*) AS SoChuyen FROM dbo.CHUYENBAY GROUP BY TrangThai ORDER BY TrangThai`),
    ]);

    // Customer: Chỉ thấy số lượng chuyến bay khai thác công khai, ẩn các chỉ số kinh doanh/hành khách/máy bay
    if (role === 'customer') {
      return res.json({
        counts: { ChuyenBay: counts[0].ChuyenBay, VeBay: null, HanhKhach: null, MayBay: null },
        flights,
        mix,
      });
    }

    res.json({ counts: counts[0], flights, mix });
  } catch (error) {
    reportError(res, error);
  }
});

async function workflowState(id, p) {
  const pool = await getPool();
  const flight = p.MaChuyenBay ? String(p.MaChuyenBay) : '';
  const ticket = p.MaVe ? String(p.MaVe) : '';
  const passenger = p.MaHanhKhach ? String(p.MaHanhKhach) : '';
  const plane = p.MaMayBay ? String(p.MaMayBay) : '';
  const employee = p.MaNV ? String(p.MaNV) : 'NV01';
  const date = p.NgayBay || '2026-10-10';
  const from = p.TuNgay || '2026-10-01';
  const to = p.DenNgay || '2026-10-31';
  const tables = [];
  const add = async (title, sqlText, inputs = []) => tables.push({ title, rows: await query(pool, sqlText, inputs) });
  const str = (name, value, size = 20) => [name, sql.VarChar(size), value];
  const dt = (name, value) => [name, sql.Date, value];

  if (['sp1-book', 'tg1-book'].includes(id)) {
    await add('Chuyến bay / tuyến bay / máy bay', `SELECT cb.MaChuyenBay,db.MaSanBayDi,db.MaSanBayDen,cb.MaMayBay,
      cb.GioKhoiHanhDK,cb.TrangThai,cb.SoGheTrong,mb.SoGhe AS SucChua,cb.GiaVePhoThong,cb.GiaVeThuongGia
      FROM dbo.CHUYENBAY cb JOIN dbo.DUONGBAY db ON db.MaDuongBay=cb.MaDuongBay JOIN dbo.MAYBAY mb ON mb.MaMayBay=cb.MaMayBay
      WHERE cb.MaChuyenBay=@id`, [str('id', flight, 5)]);
    await add('Hành khách', 'SELECT MaHanhKhach,HoTen,SoGiayTo,QuocTich FROM dbo.HANHKHACH WHERE MaHanhKhach=@id', [str('id', passenger, 10)]);
    await add('Ghế còn trống (FN2)', 'SELECT * FROM dbo.FN2_DanhSachGheTrong(@id) ORDER BY SoGhe', [str('id', flight, 5)]);
    await add('Vé hiện có trên chuyến', 'SELECT MaVe,MaHanhKhach,SoGhe,HangGhe,TrangThaiVe FROM dbo.VEBAY WHERE MaChuyenBay=@id ORDER BY SoGhe', [str('id', flight, 5)]);
    return tables;
  }
  if (id === 'tg1-cancel') {
    await add('Vé / chuyến bay / hóa đơn', `SELECT vb.MaVe,vb.MaChuyenBay,vb.MaHanhKhach,vb.SoGhe,vb.TrangThaiVe,
      cb.SoGheTrong,hd.TrangThaiThanhToan,hd.SoTien FROM dbo.VEBAY vb JOIN dbo.CHUYENBAY cb ON cb.MaChuyenBay=vb.MaChuyenBay
      LEFT JOIN dbo.HOADON hd ON hd.MaVe=vb.MaVe WHERE vb.MaVe=@id`, [str('id', ticket)]);
    return tables;
  }
  if (['sp2-status', 'tg2-test'].includes(id)) {
    await add('Chuyến bay', `SELECT MaChuyenBay,GioKhoiHanhDK,TrangThai,LyDoTrangThai FROM dbo.CHUYENBAY WHERE MaChuyenBay=@id`, [str('id', flight, 5)]);
    await add('Vé và thanh toán liên quan', `SELECT vb.MaVe,vb.SoGhe,vb.TrangThaiVe,hd.TrangThaiThanhToan,hd.SoTien
      FROM dbo.VEBAY vb LEFT JOIN dbo.HOADON hd ON hd.MaVe=vb.MaVe WHERE vb.MaChuyenBay=@id ORDER BY vb.MaVe`, [str('id', flight, 5)]);
    return tables;
  }
  if (id === 'sp3-revenue') {
    await add('Hóa đơn trong khoảng ngày', `SELECT COUNT(*) AS SoHoaDon,COALESCE(SUM(SoTien),0) AS TongTien
      FROM dbo.HOADON WHERE TrangThaiThanhToan=N'Thành công' AND NgayThanhToan>=@from AND NgayThanhToan<DATEADD(DAY,1,@to)`, [dt('from', from), dt('to', to)]);
    await add('Doanh thu theo chặng (SP3)', `SELECT db.MaDuongBay,db.MaSanBayDi,db.MaSanBayDen,COUNT(hd.MaHoaDon) AS SoHoaDon,COALESCE(SUM(hd.SoTien),0) AS DoanhThu
      FROM dbo.DUONGBAY db LEFT JOIN dbo.CHUYENBAY cb ON cb.MaDuongBay=db.MaDuongBay
      LEFT JOIN dbo.VEBAY vb ON vb.MaChuyenBay=cb.MaChuyenBay AND vb.TrangThaiVe<>N'Đã hủy'
      LEFT JOIN dbo.HOADON hd ON hd.MaVe=vb.MaVe AND hd.TrangThaiThanhToan=N'Thành công' AND hd.NgayThanhToan>=@from AND hd.NgayThanhToan<DATEADD(DAY,1,@to)
      GROUP BY db.MaDuongBay,db.MaSanBayDi,db.MaSanBayDen ORDER BY db.MaDuongBay`, [dt('from', from), dt('to', to)]);
    return tables;
  }
  if (id === 'sp4-search') {
    await add('Sân bay', 'SELECT MaSanBay,TenSanBay,ThanhPho FROM dbo.SANBAY ORDER BY MaSanBay');
    await add('Chuyến bay khớp bộ lọc', `SELECT cb.MaChuyenBay,db.MaSanBayDi,s1.TenSanBay AS SanBayDi,db.MaSanBayDen,s2.TenSanBay AS SanBayDen,
      cb.GioKhoiHanhDK,cb.GioHaCanhDK,cb.MaMayBay,cb.TrangThai,cb.SoGheTrong
      FROM dbo.CHUYENBAY cb JOIN dbo.DUONGBAY db ON db.MaDuongBay=cb.MaDuongBay
      JOIN dbo.SANBAY s1 ON s1.MaSanBay=db.MaSanBayDi JOIN dbo.SANBAY s2 ON s2.MaSanBay=db.MaSanBayDen
      WHERE db.MaSanBayDi=@di AND db.MaSanBayDen=@den AND cb.GioKhoiHanhDK>=@day AND cb.GioKhoiHanhDK<DATEADD(DAY,1,@day)
      ORDER BY cb.GioKhoiHanhDK`, [['di', sql.Char(3), p.MaSanBayDi], ['den', sql.Char(3), p.MaSanBayDen], dt('day', date)]);
    return tables;
  }
  if (id === 'sp5-crew') {
    await add('Chuyến bay', `SELECT MaChuyenBay,GioKhoiHanhDK,GioHaCanhDK,TrangThai FROM dbo.CHUYENBAY WHERE MaChuyenBay=@id`, [str('id', flight, 5)]);
    await add('Nhân viên phù hợp', `SELECT MaNV,HoTen,ChucVu,TrangThai FROM dbo.NHANVIEN WHERE MaNV=@id`, [str('id', employee, 10)]);
    await add('Các ca của nhân viên', `SELECT pc.MaChuyenBay,pc.MaNV,pc.VaiTro,pc.GioBatDau,pc.GioKetThuc
      FROM dbo.PHANCONG pc WHERE pc.MaNV=@id ORDER BY pc.GioBatDau`, [str('id', employee, 10)]);
    return tables;
  }
  if (id === 'tg3-test') {
    await add('Phân công hiện tại của nhân viên thử nghiệm', `SELECT MaChuyenBay,MaNV,VaiTro,GioBatDau,GioKetThuc
      FROM dbo.PHANCONG WHERE MaNV=@id ORDER BY GioBatDau`, [str('id', employee, 10)]);
    await add('Các chuyến dùng cho batch minh họa', `SELECT MaChuyenBay,GioKhoiHanhDK,TrangThai FROM dbo.CHUYENBAY WHERE MaChuyenBay IN ('QH156','QH312','QH402','QH510') ORDER BY GioKhoiHanhDK`);
    return tables;
  }
  if (id === 'tg4-test') {
    await add('Giá vé trước khi kích hoạt TG4', `SELECT MaChuyenBay,GiaVePhoThong,GiaVeThuongGia FROM dbo.CHUYENBAY WHERE MaChuyenBay=@id`, [str('id', flight, 5)]);
    return tables;
  }
  if (id === 'tg5-test') {
    await add('Máy bay và lịch khai thác', `SELECT mb.MaMayBay,mb.SoHieu,mb.LoaiMayBay,cb.MaChuyenBay,cb.GioKhoiHanhDK,cb.TrangThai
      FROM dbo.MAYBAY mb LEFT JOIN dbo.CHUYENBAY cb ON cb.MaMayBay=mb.MaMayBay WHERE mb.MaMayBay=@id ORDER BY cb.GioKhoiHanhDK`, [str('id', plane, 10)]);
    return tables;
  }
  if (id === 'price-update') {
    await add('Chuyến bay và giá vé hiện tại', `SELECT MaChuyenBay,GiaVePhoThong,GiaVeThuongGia,TrangThai
      FROM dbo.CHUYENBAY WHERE MaChuyenBay=@id`, [str('id', flight, 5)]);
    return tables;
  }
  if (id === 'aircraft-maintenance') {
    await add('Thông tin máy bay', `SELECT MaMayBay,SoHieu,LoaiMayBay,SoGhe,TrangThai
      FROM dbo.MAYBAY WHERE MaMayBay=@id`, [str('id', plane, 10)]);
    return tables;
  }
  if (id === 'fn1-membership') {
    await add('Hành khách', 'SELECT MaHanhKhach,HoTen,SoGiayTo,QuocTich FROM dbo.HANHKHACH WHERE MaHanhKhach=@id', [str('id', passenger, 10)]);
    await add('Vé và hóa đơn đã thanh toán', `SELECT vb.MaVe,vb.MaChuyenBay,hd.NgayThanhToan,hd.SoTien,hd.TrangThaiThanhToan,vb.TrangThaiVe
      FROM dbo.VEBAY vb JOIN dbo.HOADON hd ON hd.MaVe=vb.MaVe WHERE vb.MaHanhKhach=@id ORDER BY hd.NgayThanhToan DESC`, [str('id', passenger, 10)]);
    return tables;
  }
  if (id === 'fn2-seats') {
    await add('Chuyến bay', `SELECT cb.MaChuyenBay,cb.MaMayBay,cb.SoGheTrong,cb.TrangThai,mb.SoGhe AS SucChua
      FROM dbo.CHUYENBAY cb JOIN dbo.MAYBAY mb ON mb.MaMayBay=cb.MaMayBay WHERE cb.MaChuyenBay=@id`, [str('id', flight, 5)]);
    await add('Vé đã phát hành', 'SELECT MaVe,SoGhe,TrangThaiVe FROM dbo.VEBAY WHERE MaChuyenBay=@id ORDER BY SoGhe', [str('id', flight, 5)]);
    await add('Ghế trống hiện tại', 'SELECT * FROM dbo.FN2_DanhSachGheTrong(@id) ORDER BY SoGhe', [str('id', flight, 5)]);
    return tables;
  }
  if (id === 'fn3-aircraft') {
    await add('Máy bay', 'SELECT MaMayBay,SoHieu,LoaiMayBay,SoGhe,TrangThai FROM dbo.MAYBAY WHERE MaMayBay=@id', [str('id', plane, 10)]);
    await add('Chuyến trong tháng', `SELECT MaChuyenBay,GioKhoiHanhDK,GioHaCanhDK,TrangThai FROM dbo.CHUYENBAY
      WHERE MaMayBay=@plane AND YEAR(GioKhoiHanhDK)=@year AND MONTH(GioKhoiHanhDK)=@month ORDER BY GioKhoiHanhDK`,
      [str('plane', plane, 10), ['year', sql.Int, Number(p.Nam || 2026)], ['month', sql.Int, Number(p.Thang || 10)]]);
    return tables;
  }
  if (id === 'cs1-delay') {
    await add('Chuyến đang Delay', `SELECT cb.MaChuyenBay,cb.SoPhutTre,cb.GioKhoiHanhDK,cb.GioCatCanhTT,COUNT(vb.MaVe) AS SoVeConHieuLuc
      FROM dbo.CHUYENBAY cb LEFT JOIN dbo.VEBAY vb ON vb.MaChuyenBay=cb.MaChuyenBay AND vb.TrangThaiVe<>N'Đã hủy'
      WHERE cb.TrangThai=N'Delay' GROUP BY cb.MaChuyenBay,cb.SoPhutTre,cb.GioKhoiHanhDK,cb.GioCatCanhTT ORDER BY cb.MaChuyenBay`);
    return tables;
  }
  if (id === 'cs2-payroll') {
    await add('Phân công và nhân viên trong khoảng ngày', `SELECT pc.MaChuyenBay,pc.MaNV,nv.HoTen,pc.VaiTro,pc.GioBatDau,pc.GioKetThuc
      FROM dbo.PHANCONG pc JOIN dbo.NHANVIEN nv ON nv.MaNV=pc.MaNV
      WHERE pc.GioBatDau>=@from AND pc.GioBatDau<DATEADD(DAY,1,@to) ORDER BY pc.GioBatDau,pc.MaNV`, [dt('from', from), dt('to', to)]);
    return tables;
  }
  if (id === 'report-ticket') {
    await add('Vé / hành khách / chuyến / hóa đơn', `SELECT vb.MaVe,vb.MaDatCho,vb.SoGhe,vb.HangGhe,vb.GiaVe,vb.TrangThaiVe,hk.HoTen,
      cb.MaChuyenBay,cb.GioKhoiHanhDK,db.MaSanBayDi,db.MaSanBayDen,hd.TrangThaiThanhToan,hd.NgayThanhToan,hd.SoTien
      FROM dbo.VEBAY vb JOIN dbo.HANHKHACH hk ON hk.MaHanhKhach=vb.MaHanhKhach JOIN dbo.CHUYENBAY cb ON cb.MaChuyenBay=vb.MaChuyenBay
      JOIN dbo.DUONGBAY db ON db.MaDuongBay=cb.MaDuongBay LEFT JOIN dbo.HOADON hd ON hd.MaVe=vb.MaVe WHERE vb.MaVe=@id`, [str('id', ticket)]);
    return tables;
  }
  if (id === 'report-manifest') {
    await add('Chuyến bay và danh sách hành khách', `SELECT cb.MaChuyenBay,cb.GioKhoiHanhDK,db.MaSanBayDi,db.MaSanBayDen,vb.MaVe,vb.SoGhe,vb.HangGhe,
      hk.HoTen,hk.NgaySinh,hk.SoGiayTo,hk.QuocTich,vb.TrangThaiVe FROM dbo.CHUYENBAY cb
      JOIN dbo.DUONGBAY db ON db.MaDuongBay=cb.MaDuongBay LEFT JOIN dbo.VEBAY vb ON vb.MaChuyenBay=cb.MaChuyenBay AND vb.TrangThaiVe<>N'Đã hủy'
      LEFT JOIN dbo.HANHKHACH hk ON hk.MaHanhKhach=vb.MaHanhKhach WHERE cb.MaChuyenBay=@id ORDER BY vb.SoGhe`, [str('id', flight, 5)]);
    return tables;
  }
  if (id === 'report-crew') {
    await add('Tổ bay trong ngày', `SELECT pc.MaChuyenBay,pc.MaNV,nv.HoTen,pc.VaiTro,pc.GioBatDau,pc.GioKetThuc,
      DATEDIFF(MINUTE,pc.GioBatDau,pc.GioKetThuc)/60.0 AS SoGio FROM dbo.PHANCONG pc JOIN dbo.NHANVIEN nv ON nv.MaNV=pc.MaNV
      WHERE CONVERT(date,pc.GioBatDau)=@day ORDER BY pc.GioBatDau`, [dt('day', date)]);
    return tables;
  }
  if (id === 'report-revenue') {
    await add('Thanh toán và tuyến bay trong khoảng ngày', `SELECT db.MaDuongBay,db.MaSanBayDi,db.MaSanBayDen,hd.MaHoaDon,hd.SoTien,hd.NgayThanhToan
      FROM dbo.HOADON hd JOIN dbo.VEBAY vb ON vb.MaVe=hd.MaVe JOIN dbo.CHUYENBAY cb ON cb.MaChuyenBay=vb.MaChuyenBay
      JOIN dbo.DUONGBAY db ON db.MaDuongBay=cb.MaDuongBay WHERE hd.TrangThaiThanhToan=N'Thành công' AND vb.TrangThaiVe<>N'Đã hủy'
      AND hd.NgayThanhToan>=@from AND hd.NgayThanhToan<DATEADD(DAY,1,@to) ORDER BY db.MaDuongBay`, [dt('from', from), dt('to', to)]);
    return tables;
  }
  if (id === 'report-performance') {
    await add('Trạng thái chuyến trong khoảng ngày', `SELECT MaChuyenBay,TrangThai,GioKhoiHanhDK,GioCatCanhTT,SoPhutTre FROM dbo.CHUYENBAY
      WHERE GioKhoiHanhDK>=@from AND GioKhoiHanhDK<DATEADD(DAY,1,@to) ORDER BY GioKhoiHanhDK`, [dt('from', from), dt('to', to)]);
    return tables;
  }
  throw Object.assign(new Error('Không tìm thấy luồng nghiệp vụ: ' + id), { status: 404 });
}

app.get('/api/workflows/:id/state', async (req, res) => {
  try {
    const role = getUserRole(req);
    if (!hasPermission(role, req.params.id)) {
      return res.status(403).json({
        ok: false,
        error: {
          number: 403,
          code: 'FORBIDDEN',
          message: `Vai trò [${role}] không có quyền truy cập chức năng '${req.params.id}'.`,
        },
      });
    }
    const tables = await workflowState(req.params.id, req.query);
    res.json({ tables, refreshedAt: new Date().toISOString() });
  } catch (error) {
    if (error.status) return res.status(error.status).json({ error: { number: null, message: error.message } });
    reportError(res, error);
  }
});

async function executeWorkflow(id, p) {
  const pool = await getPool();
  const request = () => pool.request();
  let result;
  if (['sp1-book', 'tg1-book'].includes(id)) {
    const values = {
      MaVe: required(p.MaVe, 'mã vé'), MaChuyenBay: required(p.MaChuyenBay, 'chuyến bay'),
      MaHanhKhach: required(p.MaHanhKhach, 'hành khách'), MaDatCho: required(p.MaDatCho, 'mã đặt chỗ'),
      SoGhe: required(p.SoGhe, 'số ghế'), HangGhe: required(p.HangGhe, 'hạng ghế'),
    };
    const req = request().input('MaVe', sql.VarChar(20), values.MaVe).input('MaChuyenBay', sql.VarChar(5), values.MaChuyenBay)
      .input('MaHanhKhach', sql.VarChar(10), values.MaHanhKhach).input('MaDatCho', sql.VarChar(20), values.MaDatCho)
      .input('SoGhe', sql.VarChar(5), values.SoGhe).input('HangGhe', sql.NVarChar(20), values.HangGhe);
    result = await req.execute('dbo.SP1_DATCHO_TAOVE');
  } else if (id === 'tg1-cancel') {
    result = await request().input('MaVe', sql.VarChar(20), required(p.MaVe, 'mã vé'))
      .query("UPDATE dbo.VEBAY SET TrangThaiVe=N'Đã hủy' WHERE MaVe=@MaVe AND TrangThaiVe<>N'Đã hủy'; SELECT @@ROWCOUNT AS SoDongCapNhat;");
    if (!result.recordset[0].SoDongCapNhat) throw Object.assign(new Error('Không tìm thấy vé còn hiệu lực để hủy.'), { status: 404 });
  } else if (['sp2-status', 'tg2-test'].includes(id)) {
    const maChuyenBay = required(p.MaChuyenBay, 'chuyến bay');
    if (id === 'tg2-test') {
      const candidate = await request().input('MaChuyenBay', sql.VarChar(5), maChuyenBay).query(`
        SELECT COUNT(*) AS Eligible FROM dbo.CHUYENBAY
        WHERE MaChuyenBay=@MaChuyenBay AND TrangThai<>N'Đã hủy'
          AND GioKhoiHanhDK>SYSUTCDATETIME() AND GioKhoiHanhDK<DATEADD(HOUR,24,SYSUTCDATETIME())`);
      if (!candidate.recordset[0].Eligible) {
        throw Object.assign(new Error('Chọn chuyến chưa khởi hành và còn dưới 24 giờ để TG2 chặn an toàn.'), { status: 400 });
      }
    }
    result = await request().input('MaChuyenBay', sql.VarChar(5), maChuyenBay)
      .input('TrangThaiMoi', sql.NVarChar(30), id === 'tg2-test' ? 'Đã hủy' : required(p.TrangThaiMoi, 'trạng thái'))
      .input('LyDo', sql.NVarChar(500), required(p.LyDo, 'lý do')).execute('dbo.SP2_DELAY_HUY');
  } else if (id === 'sp3-revenue') {
    const from = dateValue(p.TuNgay, 'Từ ngày'); const to = dateValue(p.DenNgay, 'Đến ngày');
    result = await request().input('TuNgay', sql.Date, from).input('DenNgay', sql.Date, to).execute('dbo.SP3_TINHDOANHTHU');
  } else if (id === 'sp4-search') {
    result = await request().input('MaSanBayDi', sql.Char(3), required(p.MaSanBayDi, 'sân bay đi'))
      .input('MaSanBayDen', sql.Char(3), required(p.MaSanBayDen, 'sân bay đến')).input('NgayBay', sql.Date, dateValue(p.NgayBay, 'ngày bay'))
      .execute('dbo.SP4_TRACUUDANHSACH');
  } else if (id === 'sp5-crew') {
    result = await request().input('MaChuyenBay', sql.VarChar(5), required(p.MaChuyenBay, 'chuyến bay'))
      .input('MaNV', sql.VarChar(10), required(p.MaNV, 'nhân viên')).input('VaiTro', sql.NVarChar(30), required(p.VaiTro, 'vai trò'))
      .input('GioBatDauMoi', sql.VarChar(19), utcDateTime(p.GioBatDauMoi, 'giờ bắt đầu'))
      .input('GioKetThucMoi', sql.VarChar(19), utcDateTime(p.GioKetThucMoi, 'giờ kết thúc')).execute('dbo.SP5_PHANCONGTOBAY');
  } else if (id === 'tg3-test') {
    result = await request().query(`SET XACT_ABORT ON;
      BEGIN TRY
        BEGIN TRANSACTION;
        INSERT INTO dbo.PHANCONG(MaChuyenBay,MaNV,VaiTro,GioBatDau,GioKetThuc) VALUES
          ('QH156','NV01',N'Cơ trưởng','2026-10-15T00:00:00','2026-10-15T08:00:00'),
          ('QH312','NV01',N'Cơ trưởng','2026-10-16T00:00:00','2026-10-16T08:00:00'),
          ('QH402','NV01',N'Cơ trưởng','2026-10-16T09:00:00','2026-10-16T17:00:00'),
          ('QH510','NV01',N'Cơ trưởng','2026-10-17T00:00:00','2026-10-17T08:00:00');
        COMMIT TRANSACTION;
      END TRY
      BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
        THROW;
      END CATCH;`);
  } else if (id === 'tg4-test') {
    result = await request().input('MaChuyenBay', sql.VarChar(5), required(p.MaChuyenBay, 'chuyến bay'))
      .query('UPDATE dbo.CHUYENBAY SET GiaVeThuongGia=GiaVePhoThong WHERE MaChuyenBay=@MaChuyenBay; SELECT @@ROWCOUNT AS SoDongCapNhat;');
    if (!result.recordset[0].SoDongCapNhat) throw Object.assign(new Error('Không tìm thấy chuyến bay.'), { status: 404 });
  } else if (id === 'tg5-test') {
    const maMayBay = required(p.MaMayBay, 'máy bay');
    const candidate = await request().input('MaMayBay', sql.VarChar(10), maMayBay).query(`
      SELECT COUNT(*) AS Eligible FROM dbo.CHUYENBAY
      WHERE MaMayBay=@MaMayBay AND GioKhoiHanhDK>SYSUTCDATETIME() AND TrangThai<>N'Đã hủy'`);
    if (!candidate.recordset[0].Eligible) {
      throw Object.assign(new Error('Chọn máy bay đang có chuyến bay tương lai để TG5 chặn thao tác.'), { status: 400 });
    }
    result = await request().input('MaMayBay', sql.VarChar(10), maMayBay)
      .query('DELETE FROM dbo.MAYBAY WHERE MaMayBay=@MaMayBay; SELECT @@ROWCOUNT AS SoDongCapNhat;');
    if (!result.recordset[0].SoDongCapNhat) throw Object.assign(new Error('Máy bay không được xóa hoặc không tồn tại.'), { status: 404 });
  } else if (id === 'price-update') {
    const maChuyenBay = required(p.MaChuyenBay, 'chuyến bay');
    const giaVeMoi = Number(p.GiaVeMoi);
    if (!Number.isFinite(giaVeMoi) || giaVeMoi <= 0) throw Object.assign(new Error('Giá vé phải là số lớn hơn 0.'), { status: 400 });
    result = await request().input('MaChuyenBay', sql.VarChar(5), maChuyenBay).input('GiaVeMoi', sql.Decimal(12, 2), giaVeMoi)
      .query('UPDATE dbo.CHUYENBAY SET GiaVeThuongGia=@GiaVeMoi WHERE MaChuyenBay=@MaChuyenBay; SELECT @@ROWCOUNT AS SoDongCapNhat;');
    if (!result.recordset[0].SoDongCapNhat) throw Object.assign(new Error('Không tìm thấy chuyến bay.'), { status: 404 });
  } else if (id === 'aircraft-maintenance') {
    result = await request().input('MaMayBay', sql.VarChar(10), required(p.MaMayBay, 'máy bay'))
      .input('TrangThai', sql.NVarChar(30), required(p.TrangThai, 'trạng thái máy bay'))
      .query('UPDATE dbo.MAYBAY SET TrangThai=@TrangThai WHERE MaMayBay=@MaMayBay; SELECT @@ROWCOUNT AS SoDongCapNhat;');
    if (!result.recordset[0].SoDongCapNhat) throw Object.assign(new Error('Không tìm thấy máy bay.'), { status: 404 });
  } else if (id === 'fn1-membership') {
    result = await request().input('MaHanhKhach', sql.VarChar(10), required(p.MaHanhKhach, 'hành khách'))
      .query('SELECT dbo.FN1_HangHoiVien(@MaHanhKhach) AS HangHoiVien');
  } else if (id === 'fn2-seats') {
    result = await request().input('MaChuyenBay', sql.VarChar(5), required(p.MaChuyenBay, 'chuyến bay'))
      .query('SELECT * FROM dbo.FN2_DanhSachGheTrong(@MaChuyenBay) ORDER BY SoGhe');
  } else if (id === 'fn3-aircraft') {
    result = await request().input('MaMayBay', sql.VarChar(10), required(p.MaMayBay, 'máy bay'))
      .input('Nam', sql.Int, Number(p.Nam)).input('Thang', sql.Int, Number(p.Thang))
      .query('SELECT * FROM dbo.FN3_ThongKeMayBayTheoThang(@MaMayBay,@Nam,@Thang)');
  } else if (id === 'cs1-delay') {
    result = await request().execute('dbo.CS1_TinhBoiThuongChuyenBayDelay');
  } else if (id === 'cs2-payroll') {
    result = await request().input('TuNgay', sql.Date, dateValue(p.TuNgay, 'Từ ngày'))
      .input('DenNgay', sql.Date, dateValue(p.DenNgay, 'Đến ngày')).execute('dbo.CS2_TongHopCongNhatPhuCap');
  } else if (id.startsWith('report-')) {
    result = await runReport(id, p, pool);
  } else {
    throw Object.assign(new Error('Không tìm thấy thao tác: ' + id), { status: 404 });
  }
  return { recordsets: result.recordsets || (result.recordset ? [result.recordset] : []), rowsAffected: result.rowsAffected || [] };
}

async function runReport(id, p, pool) {
  const req = pool.request();
  if (id === 'report-ticket') {
    req.input('MaVe', sql.VarChar(20), required(p.MaVe, 'mã vé'));
    return req.query(`SELECT N'HEADER' AS Phan,N'Vé điện tử' AS TieuDe,vb.MaVe,vb.MaDatCho,cb.MaChuyenBay,db.MaSanBayDi,db.MaSanBayDen
      FROM dbo.VEBAY vb JOIN dbo.CHUYENBAY cb ON cb.MaChuyenBay=vb.MaChuyenBay JOIN dbo.DUONGBAY db ON db.MaDuongBay=cb.MaDuongBay WHERE vb.MaVe=@MaVe;
      SELECT N'DETAIL' AS Phan,hk.HoTen,hk.SoGiayTo,vb.SoGhe,vb.HangGhe,vb.GiaVe,cb.GioKhoiHanhDK,cb.GioHaCanhDK
      FROM dbo.VEBAY vb JOIN dbo.HANHKHACH hk ON hk.MaHanhKhach=vb.MaHanhKhach JOIN dbo.CHUYENBAY cb ON cb.MaChuyenBay=vb.MaChuyenBay WHERE vb.MaVe=@MaVe;
      SELECT N'FOOTER' AS Phan,vb.TrangThaiVe,hd.TrangThaiThanhToan,hd.NgayThanhToan,hd.SoTien
      FROM dbo.VEBAY vb LEFT JOIN dbo.HOADON hd ON hd.MaVe=vb.MaVe WHERE vb.MaVe=@MaVe;`);
  }
  if (id === 'report-manifest') {
    req.input('MaChuyenBay', sql.VarChar(5), required(p.MaChuyenBay, 'chuyến bay'));
    return req.query(`SELECT N'HEADER' AS Phan,N'Passenger Manifest' AS TieuDe,cb.MaChuyenBay,db.MaSanBayDi,db.MaSanBayDen,cb.GioKhoiHanhDK
      FROM dbo.CHUYENBAY cb JOIN dbo.DUONGBAY db ON db.MaDuongBay=cb.MaDuongBay WHERE cb.MaChuyenBay=@MaChuyenBay;
      SELECT N'DETAIL' AS Phan,vb.MaVe,vb.SoGhe,vb.HangGhe,hk.HoTen,hk.NgaySinh,hk.SoGiayTo,hk.QuocTich,vb.TrangThaiVe
      FROM dbo.VEBAY vb JOIN dbo.HANHKHACH hk ON hk.MaHanhKhach=vb.MaHanhKhach WHERE vb.MaChuyenBay=@MaChuyenBay AND vb.TrangThaiVe<>N'Đã hủy' ORDER BY vb.SoGhe;
      SELECT N'FOOTER' AS Phan,COUNT(*) AS TongHanhKhach,SUM(CASE WHEN TrangThaiVe=N'Đã check-in' THEN 1 ELSE 0 END) AS DaCheckIn
      FROM dbo.VEBAY WHERE MaChuyenBay=@MaChuyenBay AND TrangThaiVe<>N'Đã hủy';`);
  }
  if (id === 'report-crew') {
    req.input('NgayBay', sql.Date, dateValue(p.NgayBay, 'ngày báo cáo'));
    return req.query(`SELECT N'HEADER' AS Phan,N'Phân công phi hành đoàn' AS TieuDe,@NgayBay AS NgayBaoCao;
      SELECT N'DETAIL' AS Phan,pc.MaChuyenBay,pc.MaNV,nv.HoTen,pc.VaiTro,pc.GioBatDau,pc.GioKetThuc,DATEDIFF(MINUTE,pc.GioBatDau,pc.GioKetThuc)/60.0 AS SoGio
      FROM dbo.PHANCONG pc JOIN dbo.NHANVIEN nv ON nv.MaNV=pc.MaNV WHERE CONVERT(date,pc.GioBatDau)=@NgayBay ORDER BY pc.GioBatDau;
      SELECT N'FOOTER' AS Phan,COUNT(*) AS SoPhanCong,COUNT(DISTINCT MaChuyenBay) AS SoChuyenBay,COALESCE(SUM(DATEDIFF(MINUTE,GioBatDau,GioKetThuc))/60.0,0) AS TongGioCong
      FROM dbo.PHANCONG WHERE CONVERT(date,GioBatDau)=@NgayBay;`);
  }
  const from = dateValue(p.TuNgay, 'Từ ngày'); const to = dateValue(p.DenNgay, 'Đến ngày');
  req.input('TuNgay', sql.Date, from).input('DenNgay', sql.Date, to);
  if (id === 'report-revenue') {
    return req.query(`SELECT N'HEADER' AS Phan,N'Doanh số theo đường bay' AS TieuDe,@TuNgay AS TuNgay,@DenNgay AS DenNgay;
      SELECT N'DETAIL' AS Phan,db.MaDuongBay,db.MaSanBayDi,db.MaSanBayDen,COUNT(hd.MaHoaDon) AS SoGiaoDich,COALESCE(SUM(hd.SoTien),0) AS DoanhThu
      FROM dbo.DUONGBAY db LEFT JOIN dbo.CHUYENBAY cb ON cb.MaDuongBay=db.MaDuongBay LEFT JOIN dbo.VEBAY vb ON vb.MaChuyenBay=cb.MaChuyenBay AND vb.TrangThaiVe<>N'Đã hủy'
      LEFT JOIN dbo.HOADON hd ON hd.MaVe=vb.MaVe AND hd.TrangThaiThanhToan=N'Thành công' AND hd.NgayThanhToan>=@TuNgay AND hd.NgayThanhToan<DATEADD(DAY,1,@DenNgay)
      GROUP BY db.MaDuongBay,db.MaSanBayDi,db.MaSanBayDen ORDER BY db.MaDuongBay;
      SELECT N'FOOTER' AS Phan,COUNT(*) AS SoHoaDon,COALESCE(SUM(hd.SoTien),0) AS TongDoanhThu FROM dbo.HOADON hd
      JOIN dbo.VEBAY vb ON vb.MaVe=hd.MaVe WHERE hd.TrangThaiThanhToan=N'Thành công' AND vb.TrangThaiVe<>N'Đã hủy'
      AND hd.NgayThanhToan>=@TuNgay AND hd.NgayThanhToan<DATEADD(DAY,1,@DenNgay);`);
  }
  if (id === 'report-performance') {
    return req.query(`SELECT N'HEADER' AS Phan,N'Hiệu suất khai thác' AS TieuDe,@TuNgay AS TuNgay,@DenNgay AS DenNgay;
      SELECT N'DETAIL' AS Phan,TrangThai,COUNT(*) AS SoChuyen,CONVERT(decimal(6,2),100.0*COUNT(*)/NULLIF(SUM(COUNT(*)) OVER(),0)) AS TyLePhanTram
      FROM dbo.CHUYENBAY WHERE GioKhoiHanhDK>=@TuNgay AND GioKhoiHanhDK<DATEADD(DAY,1,@DenNgay) GROUP BY TrangThai ORDER BY TrangThai;
      SELECT N'FOOTER' AS Phan,COUNT(*) AS TongChuyenBay,SUM(CASE WHEN TrangThai=N'Đúng giờ' OR (TrangThai=N'Đã bay' AND GioCatCanhTT IS NOT NULL AND DATEDIFF(MINUTE,GioKhoiHanhDK,GioCatCanhTT)<=15) THEN 1 ELSE 0 END) AS DungGio,
      SUM(CASE WHEN TrangThai=N'Delay' OR (GioCatCanhTT IS NOT NULL AND DATEDIFF(MINUTE,GioKhoiHanhDK,GioCatCanhTT)>15) THEN 1 ELSE 0 END) AS Hoan,
      SUM(CASE WHEN TrangThai=N'Đã hủy' THEN 1 ELSE 0 END) AS Huy FROM dbo.CHUYENBAY
      WHERE GioKhoiHanhDK>=@TuNgay AND GioKhoiHanhDK<DATEADD(DAY,1,@DenNgay);`);
  }
  throw Object.assign(new Error('Không tìm thấy báo cáo.'), { status: 404 });
}

app.post('/api/workflows/:id/run', async (req, res) => {
  try {
    const role = getUserRole(req);
    if (!hasPermission(role, req.params.id)) {
      return res.status(403).json({
        ok: false,
        error: {
          number: 403,
          code: 'FORBIDDEN',
          message: `Vai trò [${role}] không có quyền thực thi chức năng '${req.params.id}'.`,
        },
      });
    }
    const result = await executeWorkflow(req.params.id, req.body || {});
    res.json({ ok: true, result, completedAt: new Date().toISOString() });
  } catch (error) {
    res.status(error.status || 200).json({ ok: false, error: sqlError(error) });
  }
});

if (process.env.NODE_ENV === 'production') {
  const dist = path.join(__dirname, '..', 'dist');
  app.use(express.static(dist));
  app.use((req, res, next) => {
    if (req.path.startsWith('/api/')) return next();
    res.sendFile(path.join(dist, 'index.html'));
  });
}

app.listen(port, '127.0.0.1', () => console.log('QLCB API running at http://localhost:' + port));
