const Database = require('better-sqlite3');

const dbPath = process.env.DB_PATH || './daysoff.db';
const db = new Database(dbPath);

db.pragma('journal_mode = WAL');

// 建表
db.exec(`
  CREATE TABLE IF NOT EXISTS exhibitions (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    user_name TEXT NOT NULL,
    name TEXT NOT NULL,
    introduction TEXT NOT NULL,
    start_date TEXT NOT NULL,
    end_date TEXT NOT NULL,
    first_picture_url TEXT,
    painting_urls TEXT NOT NULL DEFAULT '[]',
    painting_introductions TEXT NOT NULL DEFAULT '[]',
    timestamp TEXT NOT NULL
  );

  CREATE TABLE IF NOT EXISTS exhibition_reports (
    id TEXT PRIMARY KEY,
    exhibition_id TEXT NOT NULL,
    reporter_user_id TEXT NOT NULL,
    reason TEXT NOT NULL,
    timestamp TEXT NOT NULL
  );

  CREATE TABLE IF NOT EXISTS travel_ideas (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    user_name TEXT NOT NULL,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    destination TEXT NOT NULL,
    landmark TEXT NOT NULL,
    date TEXT NOT NULL,
    start_date TEXT,
    end_date TEXT,
    timestamp TEXT NOT NULL
  );

  CREATE TABLE IF NOT EXISTS block_list (
    blocker_user_id TEXT NOT NULL,
    blocked_user_id TEXT NOT NULL,
    PRIMARY KEY (blocker_user_id, blocked_user_id)
  );

  CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,
    username TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    created_at TEXT NOT NULL
  );

  -- 通用用户数据同步：每个用户按 key 存一份 JSON 数据块
  -- key 取值：works / sports_plans / sports_diary / mood_diary / packed_trips / events_matches
  CREATE TABLE IF NOT EXISTS user_data (
    user_id TEXT NOT NULL,
    data_key TEXT NOT NULL,
    json TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    PRIMARY KEY (user_id, data_key)
  );

  -- 匿名活跃统计：userId 哈希后存储，每天每用户一行，仅用于 DAU 计数
  CREATE TABLE IF NOT EXISTS daily_active (
    day TEXT NOT NULL,
    user_hash TEXT NOT NULL,
    PRIMARY KEY (day, user_hash)
  );

  -- 匿名运行事件：abnormal_exit（异常退出）/ network_error（网络错误）
  CREATE TABLE IF NOT EXISTS app_events (
    id TEXT PRIMARY KEY,
    day TEXT NOT NULL,
    type TEXT NOT NULL,
    screen TEXT NOT NULL DEFAULT '',
    detail TEXT NOT NULL DEFAULT '',
    user_hash TEXT,
    ts TEXT NOT NULL
  );

  -- 登录令牌：Bearer token → userId
  -- device_type: 'iphone' / 'ipad'，用于同账号同类型设备仅保留最新一台
  CREATE TABLE IF NOT EXISTS tokens (
    token TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    device_type TEXT NOT NULL DEFAULT 'iphone',
    created_at TEXT NOT NULL
  );

  -- 用户留言反馈
  CREATE TABLE IF NOT EXISTS feedback (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    username TEXT NOT NULL,
    email TEXT NOT NULL,
    message TEXT NOT NULL,
    timestamp TEXT NOT NULL
  );
`);

module.exports = db;
