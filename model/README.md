# Model Directory

This directory contains all database-related files including schemas, migrations, and queries.

## Structure

- `*.sql` - SQL schema files for database tables

## Tables

### Users
Location: `users.sql`

Fields:
- `id` - Primary key (auto-increment)
- `name` - User's display name
- `email` - Unique email address
- `rating` - User rating/score
- `created_at` - Timestamp of user creation
- `updated_at` - Timestamp of last update

Indexes:
- Email index for fast lookups
- Rating index for leaderboard queries

## Usage

To create the database tables, run the SQL files against your database:

```bash
psql -d your_database -f model/users.sql
```

Or using another database client of your choice.
