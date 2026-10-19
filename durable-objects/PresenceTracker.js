export class PresenceTracker {
  constructor(state, env) { this.state = state; this.users = new Map(); }
  async fetch(req) {
    const url = new URL(req.url);
    const user = url.searchParams.get('user');
    if (user) this.users.set(user, Date.now());
    return new Response(JSON.stringify([...this.users.keys()]), {
      headers: { 'Content-Type': 'application/json' },
    });
  }
}
