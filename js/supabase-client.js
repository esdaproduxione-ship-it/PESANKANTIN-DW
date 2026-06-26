// supabase/client.js - Supabase Client Configuration

const SUPABASE_URL = window.ENV?.SUPABASE_URL || 'https://cymhozqydmkwbsutifmv.supabase.co';
const SUPABASE_ANON_KEY = window.ENV?.SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN5bWhvenF5ZG1rd2JzdXRpZm12Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI0MTkyMTQsImV4cCI6MjA5Nzk5NTIxNH0.sciYSU4pul67QCysmgBcKiEHKc5xq52uoTejVF_1fV4';

// Initialize Supabase client
const supabase = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
  }
});

// ============================================================
// AUTH HELPERS
// ============================================================

const Auth = {
  async signUp({ email, password, fullName, phone, role = 'buyer' }) {
    const { data, error } = await supabase.auth.signUp({
      email,
      password,
      options: { data: { full_name: fullName, phone, role } }
    });
    return { data, error };
  },

  async signIn({ email, password }) {
    return await supabase.auth.signInWithPassword({ email, password });
  },

  async signInWithGoogle() {
    return await supabase.auth.signInWithOAuth({
      provider: 'google',
      options: { redirectTo: window.location.origin }
    });
  },

  async signOut() {
    return await supabase.auth.signOut();
  },

  async getUser() {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return null;
    const { data: profile } = await supabase
      .from('profiles').select('*').eq('id', user.id).single();
    return { ...user, profile };
  },

  onAuthChange(callback) {
    return supabase.auth.onAuthStateChange(callback);
  }
};

// ============================================================
// STORE HELPERS
// ============================================================

const Stores = {
  async getAll() {
    return await supabase.from('stores')
      .select('*, profiles(full_name, phone)')
      .eq('is_active', true).order('name');
  },

  async getOpen() {
    return await supabase.from('stores')
      .select('*, products(id, name, price, image_url, status)')
      .eq('is_active', true).eq('is_open', true);
  },

  async getBySlug(slug) {
    return await supabase.from('stores')
      .select('*, products(*), reviews(*)')
      .eq('slug', slug).single();
  },

  async getMyStore(ownerId) {
    return await supabase.from('stores')
      .select('*').eq('owner_id', ownerId).single();
  },

  async create(storeData) {
    return await supabase.from('stores').insert(storeData).select().single();
  },

  async update(id, storeData) {
    return await supabase.from('stores').update(storeData).eq('id', id).select().single();
  }
};

// ============================================================
// PRODUCT HELPERS
// ============================================================

const Products = {
  async getByStore(storeId) {
    return await supabase.from('products')
      .select('*, categories(name, icon)')
      .eq('store_id', storeId)
      .neq('status', 'inactive')
      .order('total_sold', { ascending: false });
  },

  async search(query) {
    return await supabase.from('products')
      .select('*, stores(name, slug, is_open)')
      .eq('status', 'active')
      .ilike('name', `%${query}%`)
      .limit(20);
  },

  async getPopular() {
    return await supabase.from('popular_products').select('*').limit(12);
  },

  async create(productData) {
    return await supabase.from('products').insert(productData).select().single();
  },

  async update(id, productData) {
    return await supabase.from('products').update(productData).eq('id', id);
  },

  async delete(id) {
    return await supabase.from('products').update({ status: 'inactive' }).eq('id', id);
  }
};

// ============================================================
// ORDER HELPERS
// ============================================================

const Orders = {
  async create(orderData, items) {
    const { data: order, error } = await supabase
      .from('orders').insert(orderData).select().single();
    if (error) return { error };

    const orderItems = items.map(item => ({
      order_id: order.id,
      product_id: item.product_id,
      product_name: item.name,
      product_price: item.price,
      quantity: item.quantity,
      subtotal: item.price * item.quantity,
      notes: item.notes
    }));

    const { error: itemsError } = await supabase.from('order_items').insert(orderItems);
    if (itemsError) return { error: itemsError };

    await supabase.from('order_status_history').insert({
      order_id: order.id,
      status: 'pending',
      changed_by: orderData.buyer_id
    });

    return { data: order };
  },

  async getMyOrders(buyerId) {
    return await supabase.from('orders')
      .select('*, stores(name, logo_url), order_items(*)')
      .eq('buyer_id', buyerId)
      .order('created_at', { ascending: false });
  },

  async getStoreOrders(storeId) {
    return await supabase.from('orders')
      .select('*, profiles(full_name, phone), order_items(*)')
      .eq('store_id', storeId)
      .order('created_at', { ascending: false });
  },

  async updateStatus(orderId, status, notes = null, changedBy) {
    const { data, error } = await supabase.from('orders')
      .update({ status, seller_notes: notes }).eq('id', orderId).select().single();
    if (error) return { error };

    await supabase.from('order_status_history').insert({
      order_id: orderId, status, notes, changed_by: changedBy
    });
    return { data };
  },

  async subscribeToStoreOrders(storeId, callback) {
    return supabase.channel(`store-orders-${storeId}`)
      .on('postgres_changes', {
        event: '*', schema: 'public', table: 'orders',
        filter: `store_id=eq.${storeId}`
      }, callback).subscribe();
  }
};

// ============================================================
// UPLOAD HELPERS
// ============================================================

const Storage = {
  async uploadImage(bucket, file, path) {
    const ext = file.name.split('.').pop();
    const fileName = `${path}-${Date.now()}.${ext}`;
    const { data, error } = await supabase.storage
      .from(bucket).upload(fileName, file, { upsert: true });
    if (error) return { error };
    const { data: { publicUrl } } = supabase.storage.from(bucket).getPublicUrl(fileName);
    return { url: publicUrl };
  }
};

window.KantinDB = { supabase, Auth, Stores, Products, Orders, Storage };
