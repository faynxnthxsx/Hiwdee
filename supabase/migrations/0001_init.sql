-- HiewDee — โครงฐานข้อมูลตั้งต้น
--
-- วิธีใช้: Supabase Dashboard → SQL Editor → วางทั้งไฟล์ → Run
--
-- หลักคิดด้านความปลอดภัย
-- anon key ที่ฝังอยู่ในแอปเปิดให้ใครก็ยิงเข้ามาได้ ความปลอดภัยจึงไม่ได้มาจาก
-- การซ่อน key แต่มาจาก RLS ที่บังคับกฎรายแถวในฐานข้อมูล
-- **ทุกตารางในไฟล์นี้เปิด RLS ไว้หมด** ตารางไหนลืมเปิด = เปิดให้ทั้งโลกอ่านเขียน

-- ─────────────────────────────────────────────────────────────
-- โปรไฟล์ผู้ใช้ ต่อยอดจาก auth.users ของ Supabase
-- ─────────────────────────────────────────────────────────────
create table if not exists public.profiles (
  id            uuid primary key references auth.users on delete cascade,
  display_name  text        not null default '',
  phone         text        not null default '',
  avatar_url    text,
  is_carrier    boolean     not null default false,
  is_verified   boolean     not null default false,
  -- สิทธิ์แอดมินต้องอยู่ฝั่งเซิร์ฟเวอร์เท่านั้น
  -- ห้ามให้ผู้ใช้แก้คอลัมน์นี้เอง (ดู policy ด้านล่าง)
  is_admin      boolean     not null default false,
  rating        numeric(2,1) not null default 0,
  review_count  int         not null default 0,
  wallet_balance numeric(12,2) not null default 0,
  created_at    timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "อ่านโปรไฟล์คนอื่นได้ เพราะต้องโชว์ชื่อและคะแนนในฟีด"
  on public.profiles for select
  using (true);

create policy "แก้ได้เฉพาะโปรไฟล์ตัวเอง"
  on public.profiles for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

create policy "สร้างโปรไฟล์ของตัวเองตอนสมัคร"
  on public.profiles for insert
  with check (auth.uid() = id);

-- กันผู้ใช้ยกระดับตัวเองเป็นแอดมิน
-- policy อย่างเดียวกันไม่ได้เพราะ update ผ่านได้ทั้งแถว
create or replace function public.lock_admin_flag()
returns trigger language plpgsql security definer as $$
begin
  if new.is_admin is distinct from old.is_admin then
    raise exception 'แก้สิทธิ์แอดมินจากฝั่งไคลเอนต์ไม่ได้';
  end if;
  return new;
end $$;

create trigger profiles_lock_admin
  before update on public.profiles
  for each row execute function public.lock_admin_flag();

-- ─────────────────────────────────────────────────────────────
-- คำขอฝากหิ้ว
-- ─────────────────────────────────────────────────────────────
create table if not exists public.requests (
  id                text primary key,
  requester_id      uuid not null references public.profiles on delete cascade,
  title             text not null,
  category          text not null,
  origin_type       text not null,
  origin_name       text not null,
  quantity          int  not null default 1,
  budget_max        numeric(12,2) not null,
  service_fee_offer numeric(12,2) not null,
  deadline          timestamptz not null,
  product_url       text,
  note              text not null default '',
  status            text not null default 'open',
  created_at        timestamptz not null default now()
);

alter table public.requests enable row level security;

create policy "ฟีดเปิดให้ทุกคนดู แม้ยังไม่ล็อกอิน (guest-first)"
  on public.requests for select
  using (true);

create policy "โพสต์คำขอในนามตัวเองเท่านั้น"
  on public.requests for insert
  with check (auth.uid() = requester_id);

create policy "แก้/ลบได้เฉพาะคำขอของตัวเอง"
  on public.requests for update
  using (auth.uid() = requester_id);

-- ─────────────────────────────────────────────────────────────
-- ข้อเสนอรับหิ้ว
-- ─────────────────────────────────────────────────────────────
create table if not exists public.bids (
  id               text primary key,
  request_id       text not null references public.requests on delete cascade,
  carrier_id       uuid not null references public.profiles on delete cascade,
  carrier_tier     text not null default 'identified',
  merchant_online  boolean not null default true,
  merchant_card    boolean not null default true,
  merchant_name    text not null default '',
  service_fee      numeric(12,2) not null,
  deliver_by       timestamptz not null,
  note             text not null default '',
  status           text not null default 'pending',
  created_at       timestamptz not null default now(),
  unique (request_id, carrier_id)
);

alter table public.bids enable row level security;

create policy "ข้อเสนอเปิดให้ดู เพื่อให้ผู้ฝากเทียบราคาได้"
  on public.bids for select
  using (true);

create policy "เสนอราคาในนามตัวเองเท่านั้น"
  on public.bids for insert
  with check (auth.uid() = carrier_id);

create policy "เจ้าของข้อเสนอถอนได้ / เจ้าของคำขอกดรับได้"
  on public.bids for update
  using (
    auth.uid() = carrier_id
    or auth.uid() = (select requester_id from public.requests r where r.id = request_id)
  );

-- ─────────────────────────────────────────────────────────────
-- ออเดอร์
-- ─────────────────────────────────────────────────────────────
create table if not exists public.orders (
  id             text primary key,
  request_id     text not null references public.requests on delete restrict,
  requester_id   uuid not null references public.profiles on delete restrict,
  carrier_id     uuid not null references public.profiles on delete restrict,
  carrier_tier   text not null,
  merchant_online boolean not null default true,
  merchant_card  boolean not null default true,
  merchant_name  text not null default '',
  title          text not null,
  category       text not null,
  origin_name    text not null,
  goods_cost     numeric(12,2) not null,
  service_fee    numeric(12,2) not null,
  tax            numeric(12,2) not null default 0,
  shipping       numeric(12,2) not null default 0,
  status         text not null default 'awaitingPayment',
  charge_id      text,
  created_at     timestamptz not null default now()
);

alter table public.orders enable row level security;

-- ออเดอร์เป็นข้อมูลส่วนตัว ต่างจากฟีดที่เปิดให้ดูได้
create policy "เห็นเฉพาะออเดอร์ที่ตัวเองเกี่ยวข้อง หรือเป็นแอดมิน"
  on public.orders for select
  using (
    auth.uid() in (requester_id, carrier_id)
    or exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.is_admin
    )
  );

create policy "คู่กรณีอัปเดตออเดอร์ของตัวเองได้"
  on public.orders for update
  using (
    auth.uid() in (requester_id, carrier_id)
    or exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.is_admin
    )
  );

create policy "ผู้ฝากเป็นคนสร้างออเดอร์ตอนกดรับข้อเสนอ"
  on public.orders for insert
  with check (auth.uid() = requester_id);

create table if not exists public.order_events (
  id         bigserial primary key,
  order_id   text not null references public.orders on delete cascade,
  status     text not null,
  note       text not null default '',
  at         timestamptz not null default now()
);

alter table public.order_events enable row level security;

create policy "ไทม์ไลน์เห็นได้เท่าที่เห็นออเดอร์"
  on public.order_events for select
  using (
    exists (select 1 from public.orders o where o.id = order_id)
  );

create policy "คู่กรณีเขียนไทม์ไลน์ได้"
  on public.order_events for insert
  with check (
    exists (
      select 1 from public.orders o
      where o.id = order_id and auth.uid() in (o.requester_id, o.carrier_id)
    )
  );

-- ─────────────────────────────────────────────────────────────
-- แชท — ผูกกับออเดอร์ ไม่ใช่ผูกกับคู่สนทนา
-- ─────────────────────────────────────────────────────────────
create table if not exists public.messages (
  id          uuid primary key default gen_random_uuid(),
  order_id    text not null references public.orders on delete cascade,
  sender_id   text not null,
  sender_name text not null default '',
  kind        text not null default 'text',
  text        text not null default '',
  image_url   text,
  sent_at     timestamptz not null default now()
);

create index if not exists messages_order_sent_idx
  on public.messages (order_id, sent_at);

alter table public.messages enable row level security;

create policy "อ่านแชทได้เฉพาะคู่กรณีของออเดอร์นั้น หรือแอดมิน"
  on public.messages for select
  using (
    exists (
      select 1 from public.orders o
      where o.id = order_id
        and (
          auth.uid() in (o.requester_id, o.carrier_id)
          or exists (
            select 1 from public.profiles p
            where p.id = auth.uid() and p.is_admin
          )
        )
    )
  );

create policy "ส่งข้อความได้เฉพาะคู่กรณีของออเดอร์นั้น"
  on public.messages for insert
  with check (
    exists (
      select 1 from public.orders o
      where o.id = order_id
        and auth.uid() in (o.requester_id, o.carrier_id)
    )
  );

-- ข้อความห้ามแก้ห้ามลบ เพราะเป็นหลักฐานตอนเกิดข้อพิพาท
-- ไม่ประกาศ policy สำหรับ update/delete = ทำไม่ได้เลย

-- เปิด Realtime ให้แชทเด้งเอง ไม่ต้อง polling
alter publication supabase_realtime add table public.messages;

-- ─────────────────────────────────────────────────────────────
-- ที่เก็บรูป
-- ─────────────────────────────────────────────────────────────
insert into storage.buckets (id, name, public)
values ('order-media', 'order-media', true)
on conflict (id) do nothing;

create policy "รูปเปิดให้อ่านได้ เพราะต้องโชว์ในแชทและหน้าแอดมิน"
  on storage.objects for select
  using (bucket_id = 'order-media');

create policy "อัปโหลดได้เฉพาะคนที่ล็อกอินแล้ว"
  on storage.objects for insert
  with check (
    bucket_id = 'order-media'
    and auth.role() = 'authenticated'
  );

-- หลักฐานห้ามเขียนทับหรือลบ ไม่งั้นแก้ย้อนหลังได้
-- ไม่ประกาศ policy สำหรับ update/delete = ทำไม่ได้เลย
