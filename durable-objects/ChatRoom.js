export class ChatRoom {
  constructor(state, env) { this.state = state; this.env = env; this.sessions = new Set(); }
  async fetch(req) {
    const pair = new WebSocketPair();
    const [client, server] = Object.values(pair);
    server.accept();
    this.sessions.add(server);
    server.addEventListener('message', (e) => {
      for (const s of this.sessions) { try { s.send(e.data); } catch {} }
    });
    server.addEventListener('close', () => this.sessions.delete(server));
    return new Response(null, { status: 101, webSocket: client });
  }
}
