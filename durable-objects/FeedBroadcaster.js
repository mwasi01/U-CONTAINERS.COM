export class FeedBroadcaster {
  constructor(state, env) { this.state = state; this.sessions = new Set(); }
  async fetch() { return new Response('FeedBroadcaster stub', { status: 501 }); }
}
