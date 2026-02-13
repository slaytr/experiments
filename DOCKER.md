# Docker Setup

This project uses Docker Compose to run a MySQL database server.

## Prerequisites

- Docker installed on your system
- Docker Compose installed

## Quick Start

1. Copy the example environment file:
   ```bash
   cp .env.example .env
   ```

2. (Optional) Edit `.env` to customize database credentials

3. Start the MySQL container:
   ```bash
   docker-compose up -d
   ```

4. Check if the container is running:
   ```bash
   docker-compose ps
   ```

## Database Details

- **Container Name**: hops-mysql
- **Image**: MySQL 8.0
- **Default Port**: 3306
- **Default Database**: hops_db
- **Default User**: hops_user

## Useful Commands

### Start the database
```bash
docker-compose up -d
```

### Stop the database
```bash
docker-compose down
```

### Stop and remove all data
```bash
docker-compose down -v
```

### View logs
```bash
docker-compose logs -f mysql
```

### Access MySQL CLI
```bash
docker-compose exec mysql mysql -u hops_user -p
```

## Schema Initialization

The `users` table will be automatically created when the container starts for the first time. The SQL files in the `model/` directory are automatically executed on initialization.

## Connecting from Backend

Use the following connection string in your backend:
```
mysql://hops_user:hops_password@localhost:3306/hops_db
```

Or use the individual environment variables provided in `.env`.
