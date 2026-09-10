-- ATK GMS v2.0 — barang masuk langsung dan transaksi keluar atomik.
-- Jalankan sekali melalui Supabase SQL Editor.

alter table public.receipts alter column purchase_id drop not null;
alter table public.receipts add column if not exists direct_fpp_number text;

create or replace function public.issue_item_v2(
  p_item_id bigint, p_quantity integer, p_requester text,
  p_department text, p_notes text, p_officer text
) returns public.outgoing
language plpgsql security definer set search_path = ''
as $$
declare v_row public.outgoing;
begin
  if auth.uid() is null then raise exception 'Pengguna belum login'; end if;
  if p_quantity is null or p_quantity <= 0 then raise exception 'Jumlah harus lebih dari nol'; end if;
  if nullif(trim(p_requester),'') is null then raise exception 'Nama peminta wajib diisi'; end if;
  if nullif(trim(p_department),'') is null then raise exception 'Departemen wajib dipilih'; end if;
  update public.items set stock=stock-p_quantity,updated_at=now()
    where id=p_item_id and active=true and stock>=p_quantity;
  if not found then raise exception 'Barang tidak aktif atau stok tidak mencukupi'; end if;
  insert into public.outgoing(item_id,quantity,requester,department,notes,officer,created_by)
  values(p_item_id,p_quantity,trim(p_requester),trim(p_department),nullif(trim(p_notes),''),trim(p_officer),auth.uid())
  returning * into v_row;
  return v_row;
end $$;

create or replace function public.receive_stock_direct(
  p_item_id bigint, p_quantity integer, p_received_date date,
  p_supplier text, p_fpb_number text, p_fpp_number text, p_officer text
) returns public.receipts
language plpgsql security definer set search_path = ''
as $$
declare v_row public.receipts;
begin
  if auth.uid() is null then raise exception 'Pengguna belum login'; end if;
  if p_quantity is null or p_quantity <= 0 then raise exception 'Jumlah harus lebih dari nol'; end if;
  if p_received_date is null then raise exception 'Tanggal diterima wajib diisi'; end if;
  update public.items set stock=stock+p_quantity,updated_at=now()
    where id=p_item_id and active=true;
  if not found then raise exception 'Barang tidak ditemukan atau tidak aktif'; end if;
  insert into public.receipts(purchase_id,item_id,quantity,received_date,supplier,fpb_number,officer,created_by,direct_fpp_number)
  values(null,p_item_id,p_quantity,p_received_date,trim(p_supplier),trim(p_fpb_number),trim(p_officer),auth.uid(),nullif(trim(p_fpp_number),''))
  returning * into v_row;
  return v_row;
end $$;

revoke all on function public.issue_item_v2(bigint,integer,text,text,text,text) from public, anon;
revoke all on function public.receive_stock_direct(bigint,integer,date,text,text,text,text) from public, anon;
grant execute on function public.issue_item_v2(bigint,integer,text,text,text,text) to authenticated;
grant execute on function public.receive_stock_direct(bigint,integer,date,text,text,text,text) to authenticated;
