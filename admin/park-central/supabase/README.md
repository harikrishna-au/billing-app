# Supabase Setup Instructions

## Prerequisites
- Supabase account (sign up at [app.supabase.com](https://app.supabase.com))
- Project created in Supabase
- Credentials added to `.env` file

## Step 1: Add Your Credentials

Edit the `.env` file in the project root:

```env
VITE_SUPABASE_URL=https://your-project.supabase.co
VITE_SUPABASE_ANON_KEY=your-anon-key-here
```

Get these values from:
1. Go to [Supabase Dashboard](https://app.supabase.com)
2. Select your project
3. Click **Settings** → **API**
4. Copy **Project URL** and **anon/public** key

## Step 2: Run the Database Schema

1. In Supabase Dashboard, go to **SQL Editor**
2. Click **New Query**
3. Copy the entire contents of `supabase/schema.sql`
4. Paste into the SQL Editor
5. Click **Run** or press `Ctrl/Cmd + Enter`

This will create:
- 5 tables (machines, services, machine_logs, catalog_history, payments)
- Enums for status types
- Indexes for performance
- Row Level Security policies
- Seed data with sample machines and services

## Step 3: Verify the Setup

After running the schema, verify in Supabase:

1. Go to **Table Editor**
2. You should see 5 tables
3. Click on `machines` table - you should see 4 sample machines
4. Click on `services` table - you should see sample services

## Step 4: Restart Your Dev Server

```bash
# Stop the current server (Ctrl+C)
npm run dev
```

## Step 5: Test the Application

1. Navigate to a machine's catalog page
2. Try adding, editing, and deleting services
3. Check that data persists after page refresh
4. Verify changes appear in Supabase Table Editor

## Troubleshooting

### Error: "Missing Supabase environment variables"
- Make sure `.env` file exists in project root
- Verify `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` are set
- Restart dev server after adding credentials

### Error: "relation does not exist"
- Run the schema.sql file in Supabase SQL Editor
- Make sure all queries executed successfully

### Data not showing up
- Check browser console for errors
- Verify RLS policies are set correctly
- Check Supabase logs in Dashboard → Logs

## Next Steps

Once MachineCatalog is working:
- Update remaining pages (ClientDashboard, MachineLogs, etc.)
- Remove mock data file
- Add authentication (optional)
- Customize RLS policies for production
