export class OrderChat {
  constructor(state, env) { this.state = state; this.env = env; }
  async fetch() { return new Response('OrderChat stub', { status: 501 }); }
}
