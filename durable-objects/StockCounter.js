export class StockCounter {
  constructor(state, env) { this.state = state; }
  async fetch(req) {
    const n = (await this.state.storage.get('count')) || 0;
    return new Response(JSON.stringify({ count: n }), { headers: { 'Content-Type': 'application/json' } });
  }
}
