// Tecido simulado por Verlet (massa-mola) para o edredom: gravidade, atrito,
// colisão com colchão e com o corpo de quem dorme (cápsulas em movimento).
export type Capsule = { ax: number; ay: number; az: number; bx: number; by: number; bz: number; r: number };
export type Box = { minX: number; minY: number; minZ: number; maxX: number; maxY: number; maxZ: number };

export class Cloth {
  readonly nx: number;
  readonly nz: number;
  readonly count: number;
  pos: Float32Array;
  prev: Float32Array;
  private link: Uint32Array;
  private rest: Float32Array;
  private stiff: Float32Array;

  constructor(nx: number, nz: number, x0: number, z0: number, w: number, l: number, y: number) {
    this.nx = nx;
    this.nz = nz;
    this.count = nx * nz;
    this.pos = new Float32Array(this.count * 3);
    this.prev = new Float32Array(this.count * 3);
    for (let j = 0; j < nz; j++)
      for (let i = 0; i < nx; i++) {
        const k = (j * nx + i) * 3;
        this.pos[k] = x0 + (i / (nx - 1)) * w;
        this.pos[k + 1] = y;
        this.pos[k + 2] = z0 - (j / (nz - 1)) * l;
      }
    this.prev.set(this.pos);
    const link: number[] = [];
    const rest: number[] = [];
    const stiff: number[] = [];
    const id = (i: number, j: number) => j * nx + i;
    const add = (a: number, b: number, s: number) => {
      const dx = this.pos[a * 3] - this.pos[b * 3], dy = this.pos[a * 3 + 1] - this.pos[b * 3 + 1], dz = this.pos[a * 3 + 2] - this.pos[b * 3 + 2];
      link.push(a, b);
      rest.push(Math.hypot(dx, dy, dz));
      stiff.push(s);
    };
    for (let j = 0; j < nz; j++)
      for (let i = 0; i < nx; i++) {
        if (i + 1 < nx) add(id(i, j), id(i + 1, j), 1);
        if (j + 1 < nz) add(id(i, j), id(i, j + 1), 1);
        if (i + 1 < nx && j + 1 < nz) {
          add(id(i, j), id(i + 1, j + 1), 0.6);
          add(id(i + 1, j), id(i, j + 1), 0.6);
        }
        if (i + 2 < nx) add(id(i, j), id(i + 2, j), 0.12);
        if (j + 2 < nz) add(id(i, j), id(i, j + 2), 0.12);
      }
    this.link = new Uint32Array(link);
    this.rest = new Float32Array(rest);
    this.stiff = new Float32Array(stiff);
  }

  step(dt: number, caps: Capsule[], box: Box, iterations = 7) {
    const p = this.pos, q = this.prev;
    const g = -9.8 * dt * dt;
    for (let k = 0; k < p.length; k += 3) {
      const vx = (p[k] - q[k]) * 0.985, vy = (p[k + 1] - q[k + 1]) * 0.985, vz = (p[k + 2] - q[k + 2]) * 0.985;
      q[k] = p[k];
      q[k + 1] = p[k + 1];
      q[k + 2] = p[k + 2];
      p[k] += vx;
      p[k + 1] += vy + g;
      p[k + 2] += vz;
    }
    for (let it = 0; it < iterations; it++) {
      const L = this.link, R = this.rest, S = this.stiff;
      for (let c = 0; c < R.length; c++) {
        const a = L[c * 2] * 3, b = L[c * 2 + 1] * 3;
        const dx = p[b] - p[a], dy = p[b + 1] - p[a + 1], dz = p[b + 2] - p[a + 2];
        const d = Math.hypot(dx, dy, dz) || 1e-6;
        const f = ((d - R[c]) / d) * 0.5 * S[c];
        p[a] += dx * f;
        p[a + 1] += dy * f;
        p[a + 2] += dz * f;
        p[b] -= dx * f;
        p[b + 1] -= dy * f;
        p[b + 2] -= dz * f;
      }
      this.collide(caps, box);
    }
  }

  private collide(caps: Capsule[], box: Box) {
    const p = this.pos, q = this.prev;
    const skin = 0.018;
    for (let k = 0; k < p.length; k += 3) {
      let hit = false;
      // caixa da cama: empurra pelo eixo de menor penetração
      if (p[k] > box.minX - skin && p[k] < box.maxX + skin && p[k + 1] < box.maxY + skin && p[k + 2] > box.minZ - skin && p[k + 2] < box.maxZ + skin && p[k + 1] > box.minY) {
        const pen = [p[k] - (box.minX - skin), box.maxX + skin - p[k], box.maxY + skin - p[k + 1], p[k + 2] - (box.minZ - skin), box.maxZ + skin - p[k + 2]];
        let m = 0;
        for (let i = 1; i < 5; i++) if (pen[i] < pen[m]) m = i;
        if (m === 0) p[k] = box.minX - skin;
        else if (m === 1) p[k] = box.maxX + skin;
        else if (m === 2) p[k + 1] = box.maxY + skin;
        else if (m === 3) p[k + 2] = box.minZ - skin;
        else p[k + 2] = box.maxZ + skin;
        hit = true;
      }
      if (p[k + 1] < 0.005) {
        p[k + 1] = 0.005;
        hit = true;
      }
      for (const c of caps) {
        const abx = c.bx - c.ax, aby = c.by - c.ay, abz = c.bz - c.az;
        const apx = p[k] - c.ax, apy = p[k + 1] - c.ay, apz = p[k + 2] - c.az;
        const len2 = abx * abx + aby * aby + abz * abz || 1e-6;
        let t = (apx * abx + apy * aby + apz * abz) / len2;
        t = t < 0 ? 0 : t > 1 ? 1 : t;
        const cx = c.ax + abx * t, cy = c.ay + aby * t, cz = c.az + abz * t;
        const dx = p[k] - cx, dy = p[k + 1] - cy, dz = p[k + 2] - cz;
        const d = Math.hypot(dx, dy, dz) || 1e-6;
        const R = c.r + skin;
        if (d < R) {
          const s = R / d;
          p[k] = cx + dx * s;
          p[k + 1] = cy + dy * s;
          p[k + 2] = cz + dz * s;
          hit = true;
        }
      }
      if (hit) {
        // atrito: o tecido não escorrega à toa
        q[k] += (p[k] - q[k]) * 0.4;
        q[k + 1] += (p[k + 1] - q[k + 1]) * 0.4;
        q[k + 2] += (p[k + 2] - q[k + 2]) * 0.4;
      }
    }
  }
}
