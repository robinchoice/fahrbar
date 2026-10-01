-- The chat streams messages; without this, new ones only show up after
-- reopening the chat.
alter publication supabase_realtime add table public.messages;
