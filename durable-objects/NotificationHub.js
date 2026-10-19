export class NotificationHub {
  constructor(state, env) { this.state = state; this.sessions = new Map(); }
  async fetch(req) {
    const pair = new WebSocketPair();
    const [client, server] = Object.values(pair);
    server.accept();
    const user = new URL(req.url).searchParams.get('user');
    if (user) this.sessions.set(user, server);
    return new Response(null, { status: 101, webSocket: client });
  }
}
