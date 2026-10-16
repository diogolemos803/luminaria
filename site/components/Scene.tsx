"use client";

import { useEffect, useRef } from "react";
import * as THREE from "three";
import { OBJLoader } from "three/examples/jsm/loaders/OBJLoader.js";
import { RoomEnvironment } from "three/examples/jsm/environments/RoomEnvironment.js";
import type { Mode } from "./palette";

export type SceneProps = {
  mode: Mode;
  lampColor: string;
  lampActive: boolean;
  reduced: boolean;
  onReady: () => void;
  onLampHover: (hover: boolean) => void;
  onLampTap: () => void;
  onWindowTap: () => void;
  /** posição da luminária na tela, em px relativos ao canvas */
  onLampScreen: (x: number, y: number) => void;
};

// ---------- texturas procedurais ----------
function canvasTexture(size: number, draw: (c: CanvasRenderingContext2D, s: number) => void, srgb = true) {
  const cv = document.createElement("canvas");
  cv.width = cv.height = size;
  draw(cv.getContext("2d")!, size);
  const t = new THREE.CanvasTexture(cv);
  t.wrapS = t.wrapT = THREE.RepeatWrapping;
  t.anisotropy = 8;
  if (srgb) t.colorSpace = THREE.SRGBColorSpace;
  return t;
}
const rnd = (a: number, b: number) => a + Math.random() * (b - a);

function woodTexture(base: string, dark: string) {
  return canvasTexture(512, (c, s) => {
    c.fillStyle = base;
    c.fillRect(0, 0, s, s);
    for (let i = 0; i < 260; i++) {
      c.strokeStyle = dark;
      c.globalAlpha = rnd(0.05, 0.22);
      c.lineWidth = rnd(0.6, 3);
      const y = rnd(0, s);
      c.beginPath();
      c.moveTo(0, y);
      c.bezierCurveTo(s * 0.3, y + rnd(-6, 6), s * 0.7, y + rnd(-6, 6), s, y + rnd(-4, 4));
      c.stroke();
    }
    c.globalAlpha = 1;
  });
}
function noiseTexture(size: number, fine: boolean) {
  return canvasTexture(
    size,
    (c, s) => {
      c.fillStyle = "#808080";
      c.fillRect(0, 0, s, s);
      const n = fine ? 9000 : 1800;
      for (let i = 0; i < n; i++) {
        const v = Math.floor(rnd(90, 170));
        c.fillStyle = `rgb(${v},${v},${v})`;
        const w = fine ? rnd(1, 3) : rnd(4, 14);
        c.fillRect(rnd(0, s), rnd(0, s), w, w);
      }
      if (fine) {
        c.globalAlpha = 0.16;
        for (let i = 0; i < s; i += 3) {
          c.fillStyle = i % 6 === 0 ? "#fff" : "#000";
          c.fillRect(i, 0, 1, s);
          c.fillRect(0, i, s, 1);
        }
        c.globalAlpha = 1;
      }
    },
    false,
  );
}

// ---------- colchas: campo de alturas com o corpo embaixo ----------
const BODY_X = 1.05;
const bodyProfile: [number, number, number][] = [
  // z, altura, meia-largura
  [-0.9, 0.24, 0.22], [-1.05, 0.26, 0.24], [-1.45, 0.2, 0.25], [-1.8, 0.15, 0.2], [-2.1, 0.1, 0.14], [-2.5, 0.07, 0.11],
];
function profileAt(z: number): [number, number] {
  if (z >= bodyProfile[0][0]) return [0, 1];
  for (let i = 0; i < bodyProfile.length - 1; i++) {
    const a = bodyProfile[i], b = bodyProfile[i + 1];
    if (z <= a[0] && z >= b[0]) {
      const t = (a[0] - z) / (a[0] - b[0]);
      const s = t * t * (3 - 2 * t);
      return [a[1] + (b[1] - a[1]) * s, a[2] + (b[2] - a[2]) * s];
    }
  }
  return [0, 1];
}

const NIGHT = { bg: new THREE.Color("#06070a"), sky: new THREE.Color("#7f9bc4"), hemiSky: new THREE.Color("#1b2536"), hemiGround: new THREE.Color("#0b0b0d"), window: new THREE.Color("#8fa9cc") };
const DAY = { bg: new THREE.Color("#cdbfa8"), sky: new THREE.Color("#ffd9a3"), hemiSky: new THREE.Color("#ffeacb"), hemiGround: new THREE.Color("#6f5d4a"), window: new THREE.Color("#fff3d6") };

export default function Scene(props: SceneProps) {
  const host = useRef<HTMLDivElement>(null);
  const live = useRef(props);
  live.current = props;

  useEffect(() => {
    const el = host.current!;
    const renderer = new THREE.WebGLRenderer({ antialias: true, powerPreference: "high-performance" });
    renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    renderer.shadowMap.enabled = true;
    renderer.shadowMap.type = THREE.PCFSoftShadowMap;
    renderer.toneMapping = THREE.ACESFilmicToneMapping;
    renderer.outputColorSpace = THREE.SRGBColorSpace;
    el.appendChild(renderer.domElement);
    renderer.domElement.style.display = "block";

    const scene = new THREE.Scene();
    const pmrem = new THREE.PMREMGenerator(renderer);
    scene.environment = pmrem.fromScene(new RoomEnvironment(), 0.04).texture;

    const camera = new THREE.PerspectiveCamera(48, 1, 0.05, 40);
    const camBase = new THREE.Vector3(0.12, 1.02, 1.4);
    const camTarget = new THREE.Vector3(0.62, 0.45, -2.4);
    camera.position.copy(camBase);

    // ---------- materiais ----------
    const woodTex = woodTexture("#7a5233", "#3a2412");
    const woodMat = new THREE.MeshStandardMaterial({ map: woodTex, roughness: 0.6, color: "#ffffff" });
    const darkWoodTex = woodTexture("#4a2f1c", "#1e1109");
    const darkWood = new THREE.MeshStandardMaterial({ map: darkWoodTex, roughness: 0.65 });
    const floorTex = woodTexture("#6b5036", "#2c1d10");
    floorTex.repeat.set(3, 10);
    const floorMat = new THREE.MeshStandardMaterial({ map: floorTex, roughness: 0.75 });
    const wallBump = noiseTexture(256, false);
    wallBump.repeat.set(6, 3);
    const wallMat = new THREE.MeshStandardMaterial({ color: "#cfc6b8", roughness: 0.95, bumpMap: wallBump, bumpScale: 0.6 });
    const linenBump = noiseTexture(256, true);
    linenBump.repeat.set(10, 10);
    const linen = new THREE.MeshStandardMaterial({ color: "#cdbfa9", roughness: 0.96, bumpMap: linenBump, bumpScale: 1.4 });
    const sheetMat = new THREE.MeshStandardMaterial({ color: "#d8cdb9", roughness: 0.95, bumpMap: linenBump, bumpScale: 1 });
    const skin = new THREE.MeshStandardMaterial({ color: "#a8765a", roughness: 0.7 });
    const hairMat = new THREE.MeshStandardMaterial({ color: "#1d140f", roughness: 0.9 });
    const shirt = new THREE.MeshStandardMaterial({ color: "#2a2b2e", roughness: 0.92, bumpMap: linenBump, bumpScale: 0.8 });
    const lampGlass = new THREE.MeshStandardMaterial({ color: "#3a2208", emissive: new THREE.Color("#F2B05E"), emissiveIntensity: 1.6, roughness: 0.25, });
    const windowPane = new THREE.MeshBasicMaterial({ color: NIGHT.window, toneMapped: false });

    let parent: THREE.Object3D = scene;
    const add = (geo: THREE.BufferGeometry, mat: THREE.Material, x: number, y: number, z: number, shadow = true) => {
      const m = new THREE.Mesh(geo, mat);
      m.position.set(x, y, z);
      m.castShadow = shadow;
      m.receiveShadow = true;
      parent.add(m);
      return m;
    };

    // ---------- quarto ----------
    const floor = add(new THREE.PlaneGeometry(6, 16), floorMat, 1.2, 0, -4.5, false);
    floor.rotation.x = -Math.PI / 2;
    const ceil = add(new THREE.PlaneGeometry(6, 16), wallMat, 1.2, 2.7, -4.5, false);
    ceil.rotation.x = Math.PI / 2;
    const leftWall = add(new THREE.PlaneGeometry(16, 2.7), wallMat, -1.0, 1.35, -4.5, false);
    leftWall.rotation.y = Math.PI / 2;
    const rightWall = add(new THREE.PlaneGeometry(16, 2.7), wallMat, 3.4, 1.35, -4.5, false);
    rightWall.rotation.y = -Math.PI / 2;
    const behind = add(new THREE.PlaneGeometry(6, 2.7), wallMat, 1.2, 1.35, 3.5, false);
    behind.rotation.y = Math.PI;

    // parede do fundo com janela (ponto de fuga)
    const WIN = { x: 1.5, y: 1.55, w: 1.5, h: 1.5, z: -7.2 };
    const back = new THREE.Shape();
    back.moveTo(-1.8, 0);
    back.lineTo(4.2, 0);
    back.lineTo(4.2, 2.7);
    back.lineTo(-1.8, 2.7);
    const hole = new THREE.Path();
    hole.moveTo(WIN.x - WIN.w / 2, WIN.y - WIN.h / 2);
    hole.lineTo(WIN.x + WIN.w / 2, WIN.y - WIN.h / 2);
    hole.lineTo(WIN.x + WIN.w / 2, WIN.y + WIN.h / 2);
    hole.lineTo(WIN.x - WIN.w / 2, WIN.y + WIN.h / 2);
    back.holes.push(hole);
    const backGeo = new THREE.ExtrudeGeometry(back, { depth: 0.2, bevelEnabled: false });
    add(backGeo, wallMat, 0, 0, WIN.z - 0.2, true);
    const pane = new THREE.Mesh(new THREE.PlaneGeometry(WIN.w, WIN.h), windowPane);
    pane.position.set(WIN.x, WIN.y, WIN.z - 0.4);
    scene.add(pane);
    const frameM = new THREE.MeshStandardMaterial({ color: "#e9e2d2", roughness: 0.6 });
    const bar = (w: number, h: number, x: number, y: number) => add(new THREE.BoxGeometry(w, h, 0.07), frameM, x, y, WIN.z - 0.05, false);
    bar(0.05, WIN.h, WIN.x, WIN.y);
    bar(WIN.w, 0.05, WIN.x, WIN.y);
    bar(0.06, WIN.h, WIN.x - WIN.w / 2, WIN.y);
    bar(0.06, WIN.h, WIN.x + WIN.w / 2, WIN.y);
    bar(WIN.w, 0.06, WIN.x, WIN.y + WIN.h / 2);
    bar(WIN.w, 0.06, WIN.x, WIN.y - WIN.h / 2);
    // área clicável da janela, um pouco maior
    const windowHit = new THREE.Mesh(new THREE.PlaneGeometry(WIN.w + 0.3, WIN.h + 0.3), new THREE.MeshBasicMaterial({ visible: false }));
    windowHit.position.set(WIN.x, WIN.y, WIN.z + 0.1);
    scene.add(windowHit);

    // ---------- criado-mudo ----------
    const TABLE = { x: -0.32, z: -0.15, w: 0.52, d: 0.44, h: 0.5 };
    add(new THREE.BoxGeometry(TABLE.w, 0.04, TABLE.d), darkWood, TABLE.x, TABLE.h - 0.02, TABLE.z);
    add(new THREE.BoxGeometry(TABLE.w - 0.04, TABLE.h - 0.04, TABLE.d - 0.04), darkWood, TABLE.x, (TABLE.h - 0.04) / 2, TABLE.z);
    add(new THREE.BoxGeometry(TABLE.w - 0.12, 0.17, 0.02), woodMat, TABLE.x, 0.33, TABLE.z + TABLE.d / 2 - 0.005);
    add(new THREE.BoxGeometry(0.1, 0.014, 0.02), new THREE.MeshStandardMaterial({ color: "#2a2623", metalness: 0.7, roughness: 0.4 }), TABLE.x, 0.33, TABLE.z + TABLE.d / 2 + 0.015, false);

    // ---------- cama ----------
    const bedG = new THREE.Group();
    bedG.position.z = 0.55;
    scene.add(bedG);
    parent = bedG;
    add(new THREE.BoxGeometry(1.55, 0.26, 2.25), darkWood, 1.05, 0.2, -1.4);
    add(new THREE.BoxGeometry(1.5, 0.2, 2.2), sheetMat, 1.05, 0.43, -1.4);
    // travesseiro
    const pillow = add(new THREE.SphereGeometry(0.5, 40, 24), linen, 1.05, 0.58, -0.58);
    pillow.scale.set(0.56, 0.1, 0.38);
    // pessoa dormindo de lado, de costas pra câmera, rosto virado pra luminária
    const head = add(new THREE.SphereGeometry(0.1, 32, 24), skin, 0.98, 0.7, -0.6);
    head.scale.set(0.95, 1.05, 1.1);
    const hair = add(new THREE.SphereGeometry(0.103, 32, 24, 0, Math.PI * 2, 0, Math.PI * 0.62), hairMat, 1.0, 0.715, -0.585);
    hair.scale.set(0.98, 1.06, 1.12);
    hair.rotation.x = -0.35;
    const nose = add(new THREE.SphereGeometry(0.014, 12, 10), skin, 0.885, 0.69, -0.585, false);
    nose.scale.set(1.2, 1, 1);
    const shoulder = add(new THREE.SphereGeometry(0.19, 32, 24), shirt, 1.08, 0.64, -0.86);
    shoulder.scale.set(1.0, 0.62, 0.8);
    const neck = add(new THREE.CylinderGeometry(0.045, 0.055, 0.12, 16), skin, 1.02, 0.68, -0.72, false);
    neck.rotation.z = Math.PI / 2 - 0.2;
    neck.rotation.x = 0.2;

    // edredom, com respiração
    const DW = 1.65, DL = 2.0, SX = 90, SZ = 110;
    const duvetGeo = new THREE.PlaneGeometry(DW, DL, SX, SZ);
    duvetGeo.rotateX(-Math.PI / 2);
    const duvet = new THREE.Mesh(duvetGeo, linen);
    duvet.castShadow = true;
    duvet.receiveShadow = true;
    duvet.position.set(1.05, 0.54, -1.9);
    bedG.add(duvet);
    parent = scene;
    const dpos = duvetGeo.attributes.position as THREE.BufferAttribute;
    const base = new Float32Array(dpos.count * 3);
    for (let i = 0; i < dpos.count; i++) {
      base[i * 3] = dpos.getX(i);
      base[i * 3 + 1] = dpos.getY(i);
      base[i * 3 + 2] = dpos.getZ(i);
    }
    const ph = Array.from({ length: 6 }, () => rnd(0, 6.28));
    const updateDuvet = (breath: number) => {
      for (let i = 0; i < dpos.count; i++) {
        const lx = base[i * 3], lz = base[i * 3 + 2];
        const wx = lx + 1.05, wz = lz - 1.9;
        const [a, w] = profileAt(wz);
        const dx = (wx - BODY_X) / w;
        let y = a * breath * Math.exp(-dx * dx * 1.6);
        // dobras do linho
        y += 0.009 * Math.sin(lx * 9 + ph[0] + lz * 3) * Math.cos(lz * 7 + ph[1]);
        y += 0.005 * Math.sin(lx * 17 + lz * 11 + ph[2]);
        y += 0.02 * Math.sin(lz * 5 + ph[3]) * Math.exp(-dx * dx * 0.5);
        // cai pelas laterais da cama
        const edge = Math.abs(lx) - 0.66;
        if (edge > 0) y -= Math.pow(edge, 1.4) * 3.4;
        // sobra no pé e junto ao travesseiro
        const tz = (DL / 2 + lz) / DL;
        if (tz < 0.04) y -= (0.04 - tz) * 2;
        if (lz > DL / 2 - 0.2) y -= (lz - (DL / 2 - 0.2)) * 1.4;
        dpos.setY(i, base[i * 3 + 1] + y);
      }
      dpos.needsUpdate = true;
      duvetGeo.computeVertexNormals();
    };
    updateDuvet(1);

    // ---------- luminária (modelo real, em mm) ----------
    const lampGroup = new THREE.Group();
    const LAMP_POS = new THREE.Vector3(TABLE.x, TABLE.h, TABLE.z);
    lampGroup.position.copy(LAMP_POS);
    scene.add(lampGroup);
    const lampLight = new THREE.PointLight("#F2B05E", 4, 0, 2);
    lampLight.castShadow = true;
    lampLight.shadow.mapSize.set(1024, 1024);
    lampLight.shadow.bias = -0.0008;
    lampLight.shadow.radius = 5;
    lampLight.position.set(-0.1, 0.09, 0); // dentro do vidro, em coordenadas locais da luminária
    lampGroup.add(lampLight);
    const lampHit = new THREE.Mesh(new THREE.BoxGeometry(0.4, 0.2, 0.2), new THREE.MeshBasicMaterial({ visible: false }));
    lampHit.position.set(0, 0.07, 0);
    lampGroup.add(lampHit);
    const halo = new THREE.Sprite(
      new THREE.SpriteMaterial({
        map: canvasTexture(256, (c, n) => {
          const g = c.createRadialGradient(n / 2, n / 2, 0, n / 2, n / 2, n / 2);
          g.addColorStop(0, "rgba(255,255,255,0.9)");
          g.addColorStop(0.25, "rgba(255,255,255,0.28)");
          g.addColorStop(1, "rgba(255,255,255,0)");
          c.fillStyle = g;
          c.fillRect(0, 0, n, n);
        }),
        color: "#F2B05E",
        blending: THREE.AdditiveBlending,
        depthWrite: false,
        transparent: true,
        toneMapped: false,
      }),
    );
    halo.position.set(-0.1, 0.09, 0.05);
    halo.scale.setScalar(0.5);
    lampGroup.add(halo);

    new OBJLoader().load("/models/luminaria-madeira.obj", (obj) => {
      obj.scale.setScalar(0.001);
      obj.position.set(-722.6 * 0.001, 0, 191.7 * 0.001);
      const lampWood = new THREE.MeshStandardMaterial({ map: woodTex, roughness: 0.5 });
      obj.traverse((o) => {
        const m = o as THREE.Mesh;
        if (!m.isMesh) return;
        const name = `${m.name} ${(m.material as THREE.Material)?.name ?? ""}`;
        if (name.includes("Vidro")) {
          m.material = lampGlass;
          m.castShadow = false;
        } else {
          m.material = lampWood;
          m.castShadow = true;
        }
        m.receiveShadow = true;
      });
      lampGroup.add(obj);
      live.current.onReady();
    });

    // ---------- luzes ----------
    const hemi = new THREE.HemisphereLight("#1b2536", "#0b0b0d", 0.3);
    scene.add(hemi);
    const sky = new THREE.DirectionalLight("#7f9bc4", 0.4);
    sky.position.set(2.2, 2.4, -9.5);
    sky.target.position.set(1.0, 0.2, 0);
    sky.castShadow = true;
    sky.shadow.mapSize.set(2048, 2048);
    sky.shadow.camera.left = -4;
    sky.shadow.camera.right = 4;
    sky.shadow.camera.top = 4;
    sky.shadow.camera.bottom = -4;
    sky.shadow.camera.near = 1;
    sky.shadow.camera.far = 16;
    sky.shadow.bias = -0.0004;
    sky.shadow.radius = 4;
    scene.add(sky, sky.target);

    // ---------- interação ----------
    const ray = new THREE.Raycaster();
    const ndc = new THREE.Vector2();
    const pick = (e: PointerEvent): "lamp" | "window" | null => {
      const r = renderer.domElement.getBoundingClientRect();
      ndc.set(((e.clientX - r.left) / r.width) * 2 - 1, -((e.clientY - r.top) / r.height) * 2 + 1);
      ray.setFromCamera(ndc, camera);
      const hits = ray.intersectObjects([lampHit, windowHit], false);
      if (!hits.length) return null;
      return hits[0].object === lampHit ? "lamp" : "window";
    };
    let hovering = false;
    const pointer = { x: 0, y: 0 };
    const onMove = (e: PointerEvent) => {
      pointer.x = (e.clientX / window.innerWidth) * 2 - 1;
      pointer.y = (e.clientY / window.innerHeight) * 2 - 1;
      if (e.pointerType !== "mouse") return;
      const p = pick(e);
      renderer.domElement.style.cursor = p ? "pointer" : "default";
      const h = p === "lamp";
      if (h !== hovering) {
        hovering = h;
        live.current.onLampHover(h);
      }
    };
    const onDown = (e: PointerEvent) => {
      const p = pick(e);
      if (p === "window") live.current.onWindowTap();
      else if (p === "lamp" && e.pointerType !== "mouse") live.current.onLampTap();
    };
    renderer.domElement.addEventListener("pointermove", onMove);
    renderer.domElement.addEventListener("pointerdown", onDown);

    // ---------- loop ----------
    const lampTarget = new THREE.Color("#F2B05E");
    const lampNow = new THREE.Color("#F2B05E");
    let day = 0;
    let lampOn = 1;
    let raf = 0;
    let last = performance.now();
    const t0 = last;
    const v = new THREE.Vector3();
    const tmp = new THREE.Color();

    const resize = () => {
      const w = el.clientWidth, h = el.clientHeight;
      renderer.setSize(w, h);
      camera.aspect = w / h;
      camera.fov = camera.aspect < 1 ? 70 : 48;
      camera.updateProjectionMatrix();
    };
    resize();
    const ro = new ResizeObserver(resize);
    ro.observe(el);

    const frame = (now: number) => {
      raf = requestAnimationFrame(frame);
      const dt = Math.min((now - last) / 1000, 0.1);
      last = now;
      const t = (now - t0) / 1000;
      const p = live.current;

      day += ((p.mode === "day" ? 1 : 0) - day) * (1 - Math.exp(-dt * 3.2));
      const targetOn = p.mode === "night" ? 1 : 0.0;
      lampOn += (targetOn - lampOn) * (1 - Math.exp(-dt * 4));
      lampTarget.set(p.lampColor);
      lampNow.lerp(lampTarget, 1 - Math.exp(-dt * 2.2));

      // luz da luminária, com um tremor mínimo de chama/LED
      const flicker = p.reduced ? 1 : 1 + 0.015 * Math.sin(t * 2.1) + 0.01 * Math.sin(t * 5.3);
      lampLight.color.copy(lampNow);
      halo.material.color.copy(lampNow);
      halo.material.opacity = 0.45 * lampOn * flicker;
      lampLight.intensity = 2.4 * lampOn * flicker;
      lampGlass.emissive.copy(lampNow).multiplyScalar(0.75).lerp(tmp.set("#e8dcc2"), day);
      lampGlass.emissiveIntensity = 0.12 + 1.1 * lampOn * flicker;

      // luz do céu / janela
      sky.color.copy(NIGHT.sky).lerp(DAY.sky, day);
      sky.intensity = 0.35 + 3.1 * day;
      hemi.color.copy(NIGHT.hemiSky).lerp(DAY.hemiSky, day);
      hemi.groundColor.copy(NIGHT.hemiGround).lerp(DAY.hemiGround, day);
      hemi.intensity = 0.8 + 0.5 * day;
      scene.environmentIntensity = 0.14 + 0.35 * day;
      renderer.toneMappingExposure = 0.95 + 0.1 * day;
      windowPane.color.copy(NIGHT.window).lerp(DAY.window, day).multiplyScalar(0.5 + 1.7 * day);
      scene.background = tmp.copy(NIGHT.bg).lerp(DAY.bg, day).clone();

      // respiração (~4s por ciclo) e deslocamento leve da câmera
      if (!p.reduced) {
        updateDuvet(1 + 0.045 * Math.sin((t / 4) * Math.PI * 2));
        camera.position.set(camBase.x + pointer.x * 0.05 + Math.sin(t * 0.15) * 0.02, camBase.y - pointer.y * 0.02, camBase.z);
      }
      camera.lookAt(camTarget);

      // âncora do card
      v.set(LAMP_POS.x - 0.03, LAMP_POS.y + 0.16, LAMP_POS.z).project(camera);
      p.onLampScreen((v.x * 0.5 + 0.5) * el.clientWidth, (-v.y * 0.5 + 0.5) * el.clientHeight);

      renderer.render(scene, camera);
    };
    raf = requestAnimationFrame(frame);

    return () => {
      cancelAnimationFrame(raf);
      ro.disconnect();
      renderer.domElement.removeEventListener("pointermove", onMove);
      renderer.domElement.removeEventListener("pointerdown", onDown);
      renderer.dispose();
      pmrem.dispose();
      el.removeChild(renderer.domElement);
    };
  }, []);

  return <div ref={host} className="absolute inset-0" aria-hidden="true" />;
}
