"use client";

import { useEffect, useRef } from "react";
import * as THREE from "three";
import { OBJLoader } from "three/examples/jsm/loaders/OBJLoader.js";
import { RoomEnvironment } from "three/examples/jsm/environments/RoomEnvironment.js";
import { RoundedBoxGeometry } from "three/examples/jsm/geometries/RoundedBoxGeometry.js";
import { EffectComposer } from "three/examples/jsm/postprocessing/EffectComposer.js";
import { RenderPass } from "three/examples/jsm/postprocessing/RenderPass.js";
import { UnrealBloomPass } from "three/examples/jsm/postprocessing/UnrealBloomPass.js";
import { OutputPass } from "three/examples/jsm/postprocessing/OutputPass.js";
import { Cloth, type Capsule, type Field } from "./cloth";
import { SLEEPER } from "./sleeper";
import type { Mode } from "./palette";

export type SceneProps = {
  mode: Mode;
  lampColor: string;
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
function speckTexture(base: string, count: number, spread: number) {
  return canvasTexture(512, (c, s) => {
    c.fillStyle = base;
    c.fillRect(0, 0, s, s);
    for (let i = 0; i < count; i++) {
      const v = Math.floor(rnd(-spread, spread));
      c.fillStyle = v > 0 ? `rgba(255,255,255,${v / 255})` : `rgba(0,0,0,${-v / 255})`;
      const w = rnd(1, 6);
      c.fillRect(rnd(0, s), rnd(0, s), w, w);
    }
  });
}
function weaveBump(size: number) {
  return canvasTexture(
    size,
    (c, s) => {
      c.fillStyle = "#808080";
      c.fillRect(0, 0, s, s);
      for (let i = 0; i < 9000; i++) {
        const v = Math.floor(rnd(100, 160));
        c.fillStyle = `rgb(${v},${v},${v})`;
        c.fillRect(rnd(0, s), rnd(0, s), rnd(1, 3), rnd(1, 3));
      }
      c.globalAlpha = 0.18;
      for (let i = 0; i < s; i += 3) {
        c.fillStyle = i % 6 === 0 ? "#fff" : "#000";
        c.fillRect(i, 0, 1, s);
        c.fillRect(0, i, s, 1);
      }
    },
    false,
  );
}

const NIGHT = { bg: new THREE.Color("#06070a"), sky: new THREE.Color("#7f9bc4"), hemiSky: new THREE.Color("#1b2536"), hemiGround: new THREE.Color("#0b0b0d"), window: new THREE.Color("#8fa9cc") };
const DAY = { bg: new THREE.Color("#cdbfa8"), sky: new THREE.Color("#ffd9a3"), hemiSky: new THREE.Color("#ffeacb"), hemiGround: new THREE.Color("#6f5d4a"), window: new THREE.Color("#fff3d6") };

// cápsula entre dois pontos (eixo Y do CapsuleGeometry alinhado a A→B)
function capsuleMesh(c: Capsule, mat: THREE.Material) {
  const a = new THREE.Vector3(c.ax, c.ay, c.az), b = new THREE.Vector3(c.bx, c.by, c.bz);
  const len = Math.max(a.distanceTo(b), 0.001);
  const m = new THREE.Mesh(new THREE.CapsuleGeometry(c.r, len, 12, 32), mat);
  m.castShadow = true;
  m.receiveShadow = true;
  return m;
}
function placeCapsule(m: THREE.Mesh, c: Capsule) {
  const a = new THREE.Vector3(c.ax, c.ay, c.az), b = new THREE.Vector3(c.bx, c.by, c.bz);
  m.position.copy(a).add(b).multiplyScalar(0.5);
  const dir = b.sub(a).normalize();
  m.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), dir);
}

export default function Scene(props: SceneProps) {
  const host = useRef<HTMLDivElement>(null);
  const live = useRef(props);
  live.current = props;

  useEffect(() => {
    const el = host.current!;
    const renderer = new THREE.WebGLRenderer({ antialias: false, powerPreference: "high-performance" });
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

    const composer = new EffectComposer(renderer, new THREE.WebGLRenderTarget(1, 1, { type: THREE.HalfFloatType, samples: 4 }));
    composer.addPass(new RenderPass(scene, camera));
    const bloom = new UnrealBloomPass(new THREE.Vector2(1, 1), 0.42, 0.7, 0.88);
    composer.addPass(bloom);
    composer.addPass(new OutputPass());

    // ---------- materiais ----------
    const lampWoodTex = woodTexture("#9a6a43", "#4a2c16");
    // texturas PBR CC0 (Poly Haven): linho, algodão, reboco e concreto liso
    const texLoader = new THREE.TextureLoader();
    const pbr = (name: string, rx: number, ry: number, color = "#ffffff", extra: THREE.MeshStandardMaterialParameters = {}) => {
      const load = (suffix: string, srgb: boolean) => {
        const t = texLoader.load(`/tex/${name}_${suffix}.jpg`);
        t.wrapS = t.wrapT = THREE.RepeatWrapping;
        t.repeat.set(rx, ry);
        t.anisotropy = 8;
        if (srgb) t.colorSpace = THREE.SRGBColorSpace;
        return t;
      };
      return new THREE.MeshStandardMaterial({ map: load("diff", true), normalMap: load("nor", false), roughnessMap: load("rough", false), color, ...extra });
    };
    const wallMat = pbr("wall", 3, 2, "#f2eee8");
    const floorMat = pbr("floor", 3, 8, "#c9c2b8");
    const pedestalMat = pbr("wall", 1.5, 1, "#f6f1e8");
    const frameFabric = pbr("linen", 2, 2, "#9b9288");
    const sheetMat = pbr("linen", 1.4, 2.2, "#ffffff");
    const duvetMat = pbr("linen", 1.6, 1.6, "#ffffff", { side: THREE.DoubleSide });
    const pillowMat = pbr("linen", 1.2, 1.2, "#ffffff");
        const hairMat = new THREE.MeshStandardMaterial({ color: "#1d140f", roughness: 0.85 });
    const shirt = pbr("linen", 6, 6, "#55575d");
    const lampGlass = new THREE.MeshStandardMaterial({ color: "#3a2208", emissive: new THREE.Color("#F2B05E"), emissiveIntensity: 2.4, roughness: 0.3 });
    const windowPane = new THREE.MeshBasicMaterial({ color: NIGHT.window, toneMapped: false });
    const frameM = new THREE.MeshStandardMaterial({ color: "#e9e2d2", roughness: 0.6 });

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

    // parede do fundo com janela (no ponto de fuga)
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
    add(new THREE.ExtrudeGeometry(back, { depth: 0.2, bevelEnabled: false }), wallMat, 0, 0, WIN.z - 0.2, true);
    const pane = new THREE.Mesh(new THREE.PlaneGeometry(WIN.w, WIN.h), windowPane);
    pane.position.set(WIN.x, WIN.y, WIN.z - 0.4);
    scene.add(pane);
    const bar = (w: number, h: number, x: number, y: number) => add(new THREE.BoxGeometry(w, h, 0.07), frameM, x, y, WIN.z - 0.05, false);
    bar(0.05, WIN.h, WIN.x, WIN.y);
    bar(WIN.w, 0.05, WIN.x, WIN.y);
    bar(0.06, WIN.h, WIN.x - WIN.w / 2, WIN.y);
    bar(0.06, WIN.h, WIN.x + WIN.w / 2, WIN.y);
    bar(WIN.w, 0.06, WIN.x, WIN.y + WIN.h / 2);
    bar(WIN.w, 0.06, WIN.x, WIN.y - WIN.h / 2);
    const windowHit = new THREE.Mesh(new THREE.PlaneGeometry(WIN.w + 0.3, WIN.h + 0.3), new THREE.MeshBasicMaterial({ visible: false }));
    windowHit.position.set(WIN.x, WIN.y, WIN.z + 0.1);
    scene.add(windowHit);

    // ---------- pedestal de microcimento (sem móvel de madeira) ----------
    const TABLE = { x: -0.32, z: -0.15, h: 0.5 };
    add(new THREE.CylinderGeometry(0.27, 0.27, TABLE.h, 64), pedestalMat, TABLE.x, TABLE.h / 2, TABLE.z);

    // ---------- cama de tecido ----------
    const bedG = new THREE.Group();
    bedG.position.z = 0.55;
    scene.add(bedG);
    parent = bedG;
    add(new RoundedBoxGeometry(1.56, 0.34, 2.26, 6, 0.05), frameFabric, 1.05, 0.17, -1.4);
    add(new RoundedBoxGeometry(1.5, 0.22, 2.2, 6, 0.07), sheetMat, 1.05, 0.43, -1.4);
    const MATTRESS_TOP = 0.54;

    // travesseiro, amassado pela cabeça
    const pillowGeo = new THREE.SphereGeometry(1, 56, 36);
    const pillow = new THREE.Mesh(pillowGeo, pillowMat);
    pillow.position.set(1.2, 0.595, -0.63);
    pillow.scale.set(0.36, 0.088, 0.22);
    pillow.castShadow = true;
    pillow.receiveShadow = true;
    bedG.add(pillow);
    const pBase = Float32Array.from(pillowGeo.attributes.position.array as ArrayLike<number>);
    const pPos = pillowGeo.attributes.position as THREE.BufferAttribute;

    // pessoa dormindo de lado, de costas pra câmera (MakeHuman base mesh, CC0, posada por esqueleto)
    const HEAD = new THREE.Vector3(...SLEEPER.headCenter);
    const sleeper = new THREE.Group();
    bedG.add(sleeper);
    const skinMat = new THREE.MeshStandardMaterial({ color: "#b4826a", roughness: 0.62 });
    const loader = new OBJLoader();
    const loadPart = (file: string, mat: THREE.Material) =>
      loader.load(`/models/${file}`, (o) => {
        o.traverse((c) => {
          const m = c as THREE.Mesh;
          if (!m.isMesh) return;
          m.material = mat;
          m.castShadow = true;
          m.receiveShadow = true;
        });
        sleeper.add(o);
      });
    loadPart("sleeper_skin.obj", skinMat);
    loadPart("sleeper_hair.obj", hairMat);
    loadPart("sleeper_shirt.obj", shirt);

    // edredom: tecido simulado (Verlet)
    const cloth = new Cloth(42, 46, 0.1, -0.6, 1.9, 2.1, 1.05);
    const bodyField: Field = { ...SLEEPER.hf, ox: 0, breath: 0 };
    const noCaps: Capsule[] = [];
    const bedBox = { minX: 0.27, minY: 0, minZ: -2.53, maxX: 1.83, maxY: MATTRESS_TOP, maxZ: -0.27 };
    const cGeo = new THREE.BufferGeometry();
    cGeo.setAttribute("position", new THREE.BufferAttribute(cloth.pos, 3));
    const uv = new Float32Array(cloth.count * 2);
    for (let j = 0; j < cloth.nz; j++)
      for (let i = 0; i < cloth.nx; i++) {
        uv[(j * cloth.nx + i) * 2] = (i / (cloth.nx - 1)) * 1.9;
        uv[(j * cloth.nx + i) * 2 + 1] = (j / (cloth.nz - 1)) * 2;
      }
    cGeo.setAttribute("uv", new THREE.BufferAttribute(uv, 2));
    const idx: number[] = [];
    for (let j = 0; j < cloth.nz - 1; j++)
      for (let i = 0; i < cloth.nx - 1; i++) {
        const a = j * cloth.nx + i, b = a + 1, c = a + cloth.nx, d = c + 1;
        idx.push(a, c, b, b, c, d);
      }
    cGeo.setIndex(idx);
    const duvet = new THREE.Mesh(cGeo, duvetMat);
    duvet.castShadow = true;
    duvet.receiveShadow = true;
    duvet.frustumCulled = false;
    bedG.add(duvet);
    parent = scene;

    // movimento de quem dorme: respiração + virar de vez em quando
    let shift = 0, shiftTarget = 0, nextShift = 12 + Math.random() * 10;
    const updateBody = (t: number, dt: number) => {
      shift += (shiftTarget - shift) * (1 - Math.exp(-dt * 0.7));
      const br = Math.sin((t / 4) * Math.PI * 2);
      const roll = shift * 0.03;
      bodyField.ox = roll;
      bodyField.breath = 0.01 * br;
      sleeper.position.set(roll, roll * 0.3, 0);
    };
    updateBody(0, 0);
    // o travesseiro afunda onde a cabeça apoia; molinha suave
    let dent = 0;
    const updatePillow = () => {
      const target = 0.05;
      dent += (target - dent) * 0.08;
      const cx = (HEAD.x - 1.2) / 0.36, cz = (HEAD.z + 0.63) / 0.22;
      for (let i = 0; i < pPos.count; i++) {
        const x = pBase[i * 3], y = pBase[i * 3 + 1], z = pBase[i * 3 + 2];
        const d2 = (x - cx) * (x - cx) + (z - cz) * (z - cz);
        const k = y > 0 ? Math.exp(-d2 * 3.2) * (dent / 0.09) * 2.2 : 0;
        pPos.setY(i, y - Math.min(k, 1.15) * y * 0.85);
      }
      pPos.needsUpdate = true;
      pillowGeo.computeVertexNormals();
    };
    for (let i = 0; i < 80; i++) updatePillow();
    // deixa o edredom assentar antes da primeira imagem
    for (let i = 0; i < 260; i++) cloth.step(1 / 60, noCaps, bedBox, 8, bodyField);
    const cPos = cGeo.attributes.position as THREE.BufferAttribute;
    cPos.needsUpdate = true;
    cGeo.computeVertexNormals();

    // ---------- luminária (modelo real, em mm) ----------
    const lampGroup = new THREE.Group();
    const LAMP_POS = new THREE.Vector3(TABLE.x, TABLE.h, TABLE.z);
    lampGroup.position.copy(LAMP_POS);
    scene.add(lampGroup);
    const lampLight = new THREE.PointLight("#F2B05E", 3, 0, 2);
    lampLight.castShadow = true;
    lampLight.shadow.mapSize.set(1024, 1024);
    lampLight.shadow.bias = -0.0005;
    lampLight.shadow.normalBias = 0.03;
    lampLight.shadow.radius = 5;
    lampLight.position.set(-0.1, 0.09, 0); // dentro do vidro
    lampGroup.add(lampLight);
    const lampHit = new THREE.Mesh(new THREE.BoxGeometry(0.4, 0.2, 0.2), new THREE.MeshBasicMaterial({ visible: false }));
    lampHit.position.set(0, 0.07, 0);
    lampGroup.add(lampHit);
    const halo = new THREE.Sprite(
      new THREE.SpriteMaterial({
        map: canvasTexture(256, (c, n) => {
          const g = c.createRadialGradient(n / 2, n / 2, 0, n / 2, n / 2, n / 2);
          g.addColorStop(0, "rgba(255,255,255,0.8)");
          g.addColorStop(0.3, "rgba(255,255,255,0.2)");
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
    halo.position.set(-0.1, 0.09, 0.08);
    halo.scale.setScalar(0.55);
    lampGroup.add(halo);

    new OBJLoader().load("/models/luminaria-madeira.obj", (obj) => {
      obj.scale.setScalar(0.001);
      obj.position.set(-722.6 * 0.001, 0, 191.7 * 0.001);
      const lampWood = new THREE.MeshStandardMaterial({ map: lampWoodTex, roughness: 0.5 });
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
    Object.assign(sky.shadow.camera, { left: -4, right: 4, top: 4, bottom: -4, near: 1, far: 16 });
    sky.shadow.bias = -0.0004;
    sky.shadow.normalBias = 0.03;
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
    let acc = 0;
    const v = new THREE.Vector3();
    const tmp = new THREE.Color();

    const resize = () => {
      const w = el.clientWidth, h = el.clientHeight;
      renderer.setSize(w, h);
      composer.setSize(w, h);
      bloom.resolution.set(w, h);
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
      lampOn += ((p.mode === "night" ? 1 : 0) - lampOn) * (1 - Math.exp(-dt * 4));
      lampTarget.set(p.lampColor);
      lampNow.lerp(lampTarget, 1 - Math.exp(-dt * 2.2));

      // a luminária acende o quarto na cor escolhida
      const flicker = p.reduced ? 1 : 1 + 0.012 * Math.sin(t * 2.1) + 0.008 * Math.sin(t * 5.3);
      lampLight.color.copy(lampNow);
      lampLight.intensity = 3.2 * lampOn * flicker;
      halo.material.color.copy(lampNow);
      halo.material.opacity = 0.4 * lampOn * flicker;
      lampGlass.emissive.copy(lampNow).multiplyScalar(0.8).lerp(tmp.set("#e8dcc2"), day);
      lampGlass.emissiveIntensity = 0.12 + 2.3 * lampOn * flicker;

      // luz do céu / janela
      sky.color.copy(NIGHT.sky).lerp(DAY.sky, day);
      sky.intensity = 0.35 + 3.1 * day;
      hemi.color.copy(NIGHT.hemiSky).lerp(DAY.hemiSky, day);
      hemi.groundColor.copy(NIGHT.hemiGround).lerp(DAY.hemiGround, day);
      hemi.intensity = 0.8 + 0.5 * day;
      scene.environmentIntensity = 0.14 + 0.35 * day;
      renderer.toneMappingExposure = 0.95 + 0.1 * day;
      bloom.strength = 0.42 - 0.3 * day;
      windowPane.color.copy(NIGHT.window).lerp(DAY.window, day).multiplyScalar(0.5 + 1.1 * day);
      scene.background = tmp.copy(NIGHT.bg).lerp(DAY.bg, day).clone();

      // física: quem dorme respira e se vira; o edredom acompanha
      if (!p.reduced) {
        if (t > nextShift) {
          shiftTarget = shiftTarget === 0 ? 1 : 0;
          nextShift = t + 14 + Math.random() * 14;
        }
        updateBody(t, dt);
        acc += dt;
        let steps = 0;
        while (acc >= 1 / 60 && steps < 2) {
          cloth.step(1 / 60, noCaps, bedBox, 6, bodyField);
          acc -= 1 / 60;
          steps++;
        }
        if (acc > 0.1) acc = 0;
        cPos.needsUpdate = true;
        cGeo.computeVertexNormals();
        updatePillow();
        camera.position.set(camBase.x + pointer.x * 0.05 + Math.sin(t * 0.15) * 0.02, camBase.y - pointer.y * 0.02, camBase.z);
      }
      camera.lookAt(camTarget);

      v.set(LAMP_POS.x - 0.03, LAMP_POS.y + 0.16, LAMP_POS.z).project(camera);
      p.onLampScreen((v.x * 0.5 + 0.5) * el.clientWidth, (-v.y * 0.5 + 0.5) * el.clientHeight);

      composer.render();
    };
    raf = requestAnimationFrame(frame);

    return () => {
      cancelAnimationFrame(raf);
      ro.disconnect();
      renderer.domElement.removeEventListener("pointermove", onMove);
      renderer.domElement.removeEventListener("pointerdown", onDown);
      composer.dispose();
      renderer.dispose();
      pmrem.dispose();
      el.removeChild(renderer.domElement);
    };
  }, []);

  return <div ref={host} className="absolute inset-0" aria-hidden="true" />;
}
