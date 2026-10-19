export class ProductChat {
  constructor(state, env) { this.state = state; this.env = env; }
  async fetch() { return new Response('ProductChat stub', { status: 501 }); }
}
