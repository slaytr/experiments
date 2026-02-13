-- Housekeeping Tasks Table Schema (MySQL)
CREATE TABLE IF NOT EXISTS housekeeping_tasks (
  id INT AUTO_INCREMENT PRIMARY KEY,
  room_id INT NOT NULL,
  assigned_user_id INT NOT NULL,
  task_date DATE NOT NULL,
  task_type ENUM('cleaning', 'maintenance', 'inspection', 'turndown') DEFAULT 'cleaning',
  priority ENUM('low', 'medium', 'high', 'urgent') DEFAULT 'medium',
  status ENUM('pending', 'in_progress', 'completed', 'cancelled') DEFAULT 'pending',
  notes TEXT,
  started_at TIMESTAMP NULL,
  completed_at TIMESTAMP NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE CASCADE,
  FOREIGN KEY (assigned_user_id) REFERENCES users(id) ON DELETE RESTRICT,
  INDEX idx_housekeeping_room (room_id),
  INDEX idx_housekeeping_user (assigned_user_id),
  INDEX idx_housekeeping_date (task_date),
  INDEX idx_housekeeping_status (status),
  UNIQUE KEY unique_room_date_type (room_id, task_date, task_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
