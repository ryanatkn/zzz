<script lang="ts">
  /**
   * Svelte 5 AI Control Interface for Hex Game
   * 
   * Provides a visual interface for controlling the game using the AI control system.
   * Uses Svelte 5 runes for reactive state management.
   */
  
  import { onMount, onDestroy } from 'svelte';
  import AIController, { type Vec2, Keys, MouseButtons } from './ai_control_example';
  
  // Reactive state using Svelte 5 runes
  let controller = $state<AIController | null>(null);
  let connected = $state(false);
  let currentFrame = $state(0);
  let mouseTarget = $state<Vec2>({ x: 400, y: 300 });
  let isRecording = $state(false);
  let recordedCommands = $state<any[]>([]);
  let commandHistory = $state<string[]>([]);
  let selectedSpell = $state(0);
  
  // Movement state
  let movement = $state({
    up: false,
    down: false,
    left: false,
    right: false,
    walk: false
  });
  
  // Combat state
  let shooting = $state(false);
  let autoShoot = $state(false);
  let shootInterval: number | null = null;
  
  // Macros
  let macros = $state([
    { name: 'Square Pattern', fn: moveSquare },
    { name: 'Circle Strafe', fn: circleStrafe },
    { name: 'Shoot Circle', fn: shootCircle },
    { name: 'Portal Rush', fn: portalRush }
  ]);
  
  // Frame update interval
  let frameInterval: number | null = null;
  
  onMount(async () => {
    controller = new AIController();
    await connect();
    
    // Update frame counter
    frameInterval = setInterval(() => {
      if (controller && connected) {
        currentFrame = controller.getCurrentFrame();
      }
    }, 100);
  });
  
  onDestroy(() => {
    if (frameInterval) clearInterval(frameInterval);
    if (shootInterval) clearInterval(shootInterval);
    if (controller) controller.disconnect();
  });
  
  async function connect() {
    if (!controller) return;
    
    try {
      await controller.connect();
      connected = true;
      addToHistory('Connected to game');
    } catch (error) {
      console.error('Failed to connect:', error);
      addToHistory(`Error: ${error}`);
    }
  }
  
  function disconnect() {
    if (!controller) return;
    
    controller.disconnect();
    connected = false;
    addToHistory('Disconnected from game');
  }
  
  function sendMovement() {
    if (!controller || !connected) return;
    
    let keys = 0n;
    
    if (movement.up) keys |= 1n << BigInt(Keys.W);
    if (movement.down) keys |= 1n << BigInt(Keys.S);
    if (movement.left) keys |= 1n << BigInt(Keys.A);
    if (movement.right) keys |= 1n << BigInt(Keys.D);
    if (movement.walk) keys |= 1n << BigInt(Keys.LSHIFT);
    
    const cmd = {
      frame: 0,
      keys,
      mouseX: mouseTarget.x,
      mouseY: mouseTarget.y,
      buttons: 0
    };
    
    controller.sendCommand(cmd);
    
    if (isRecording) {
      recordedCommands.push({ cmd, timestamp: Date.now() });
    }
  }
  
  function startShooting() {
    if (!controller || !connected) return;
    
    shooting = true;
    
    const shoot = () => {
      if (!shooting || !controller) return;
      
      const cmd = controller.shoot(mouseTarget, true);
      controller.sendCommand(cmd);
      addToHistory(`Shoot at (${mouseTarget.x.toFixed(0)}, ${mouseTarget.y.toFixed(0)})`);
      
      if (isRecording) {
        recordedCommands.push({ cmd, timestamp: Date.now() });
      }
    };
    
    shoot();
    
    if (autoShoot) {
      shootInterval = setInterval(shoot, 150);
    }
  }
  
  function stopShooting() {
    shooting = false;
    
    if (shootInterval) {
      clearInterval(shootInterval);
      shootInterval = null;
    }
    
    if (controller && connected) {
      const cmd = controller.shoot(mouseTarget, false);
      controller.sendCommand(cmd);
    }
  }
  
  function castSpell(selfCast: boolean = false) {
    if (!controller || !connected) return;
    
    const cmd = controller.castSpell(selectedSpell, mouseTarget, selfCast);
    controller.sendCommand(cmd);
    addToHistory(`Cast spell ${selectedSpell + 1} at (${mouseTarget.x.toFixed(0)}, ${mouseTarget.y.toFixed(0)})${selfCast ? ' (self)' : ''}`);
    
    if (isRecording) {
      recordedCommands.push({ cmd, timestamp: Date.now() });
    }
  }
  
  function toggleRecording() {
    isRecording = !isRecording;
    
    if (isRecording) {
      recordedCommands = [];
      addToHistory('Recording started');
    } else {
      addToHistory(`Recording stopped (${recordedCommands.length} commands)`);
    }
  }
  
  async function playRecording() {
    if (!controller || !connected || recordedCommands.length === 0) return;
    
    addToHistory('Playing recording...');
    
    for (let i = 0; i < recordedCommands.length; i++) {
      const { cmd, timestamp } = recordedCommands[i];
      
      // Calculate delay to next command
      const delay = i < recordedCommands.length - 1
        ? recordedCommands[i + 1].timestamp - timestamp
        : 0;
      
      controller.sendCommand(cmd);
      
      if (delay > 0) {
        await new Promise(r => setTimeout(r, Math.min(delay, 1000)));
      }
    }
    
    addToHistory('Recording playback complete');
  }
  
  function clearCommands() {
    if (!controller || !connected) return;
    
    controller.clear();
    addToHistory('Cleared command buffer');
  }
  
  function addToHistory(message: string) {
    commandHistory = [...commandHistory.slice(-9), message];
  }
  
  // Macro functions
  async function moveSquare() {
    if (!controller) return;
    
    addToHistory('Executing square pattern...');
    
    const moves = [
      { dir: 'right', duration: 1000 },
      { dir: 'down', duration: 1000 },
      { dir: 'left', duration: 1000 },
      { dir: 'up', duration: 1000 }
    ];
    
    for (const { dir, duration } of moves) {
      const steps = duration / 16;
      for (let i = 0; i < steps; i++) {
        controller.sendCommand(controller.move(dir as any));
        await new Promise(r => setTimeout(r, 16));
      }
    }
    
    controller.sendCommand(controller.move('stop'));
    addToHistory('Square pattern complete');
  }
  
  async function circleStrafe() {
    if (!controller) return;
    
    addToHistory('Circle strafing...');
    
    for (let angle = 0; angle < 360; angle += 5) {
      const rad = angle * Math.PI / 180;
      const target = {
        x: 400 + 150 * Math.cos(rad),
        y: 300 + 150 * Math.sin(rad)
      };
      
      await controller.moveTo(target, 2);
      await new Promise(r => setTimeout(r, 50));
    }
    
    addToHistory('Circle strafe complete');
  }
  
  async function shootCircle() {
    if (!controller) return;
    
    addToHistory('Shooting in circle...');
    
    const targets: Vec2[] = [];
    for (let angle = 0; angle < 360; angle += 30) {
      const rad = angle * Math.PI / 180;
      targets.push({
        x: 400 + 200 * Math.cos(rad),
        y: 300 + 200 * Math.sin(rad)
      });
    }
    
    await controller.shootPattern(targets);
    addToHistory('Circle shooting complete');
  }
  
  async function portalRush() {
    if (!controller) return;
    
    addToHistory('Rushing to portal...');
    
    // Move right quickly
    for (let i = 0; i < 120; i++) {
      controller.sendCommand(controller.move('right'));
      await new Promise(r => setTimeout(r, 8));
    }
    
    controller.sendCommand(controller.move('stop'));
    addToHistory('Portal rush complete');
  }
  
  // Mouse target canvas handling
  function handleCanvasClick(event: MouseEvent) {
    const canvas = event.target as HTMLCanvasElement;
    const rect = canvas.getBoundingClientRect();
    mouseTarget = {
      x: ((event.clientX - rect.left) / rect.width) * 800,
      y: ((event.clientY - rect.top) / rect.height) * 600
    };
  }
  
  // Keyboard handlers
  function handleKeyDown(event: KeyboardEvent) {
    if (!connected) return;
    
    switch(event.key.toLowerCase()) {
      case 'w': movement.up = true; break;
      case 's': movement.down = true; break;
      case 'a': movement.left = true; break;
      case 'd': movement.right = true; break;
      case 'shift': movement.walk = true; break;
    }
    
    sendMovement();
  }
  
  function handleKeyUp(event: KeyboardEvent) {
    if (!connected) return;
    
    switch(event.key.toLowerCase()) {
      case 'w': movement.up = false; break;
      case 's': movement.down = false; break;
      case 'a': movement.left = false; break;
      case 'd': movement.right = false; break;
      case 'shift': movement.walk = false; break;
    }
    
    sendMovement();
  }
  
  // Reactive canvas drawing
  $effect(() => {
    const canvas = document.getElementById('targetCanvas') as HTMLCanvasElement;
    if (!canvas) return;
    
    const ctx = canvas.getContext('2d');
    if (!ctx) return;
    
    // Clear canvas
    ctx.fillStyle = '#1a1a2e';
    ctx.fillRect(0, 0, 800, 600);
    
    // Draw grid
    ctx.strokeStyle = '#16213e';
    ctx.lineWidth = 1;
    for (let x = 0; x < 800; x += 50) {
      ctx.beginPath();
      ctx.moveTo(x, 0);
      ctx.lineTo(x, 600);
      ctx.stroke();
    }
    for (let y = 0; y < 600; y += 50) {
      ctx.beginPath();
      ctx.moveTo(0, y);
      ctx.lineTo(800, y);
      ctx.stroke();
    }
    
    // Draw crosshair at target
    ctx.strokeStyle = '#ff0000';
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(mouseTarget.x - 10, mouseTarget.y);
    ctx.lineTo(mouseTarget.x + 10, mouseTarget.y);
    ctx.moveTo(mouseTarget.x, mouseTarget.y - 10);
    ctx.lineTo(mouseTarget.x, mouseTarget.y + 10);
    ctx.stroke();
    
    // Draw target circle
    ctx.strokeStyle = '#ff6b6b';
    ctx.beginPath();
    ctx.arc(mouseTarget.x, mouseTarget.y, 20, 0, Math.PI * 2);
    ctx.stroke();
  });
</script>

<svelte:window on:keydown={handleKeyDown} on:keyup={handleKeyUp} />

<div class="ai-control-panel">
  <h1>🎮 Hex Game AI Control</h1>
  
  <div class="status-bar">
    <span class="status" class:connected>
      {connected ? '🟢 Connected' : '🔴 Disconnected'}
    </span>
    <span>Frame: {currentFrame}</span>
    <span>Target: ({mouseTarget.x.toFixed(0)}, {mouseTarget.y.toFixed(0)})</span>
    {#if isRecording}
      <span class="recording">🔴 REC ({recordedCommands.length})</span>
    {/if}
  </div>
  
  <div class="control-sections">
    <!-- Connection -->
    <section>
      <h2>Connection</h2>
      <div class="button-group">
        <button on:click={connect} disabled={connected}>Connect</button>
        <button on:click={disconnect} disabled={!connected}>Disconnect</button>
        <button on:click={clearCommands} disabled={!connected}>Clear Buffer</button>
      </div>
    </section>
    
    <!-- Movement Controls -->
    <section>
      <h2>Movement</h2>
      <div class="dpad">
        <button 
          class="dpad-up" 
          class:active={movement.up}
          on:pointerdown={() => { movement.up = true; sendMovement(); }}
          on:pointerup={() => { movement.up = false; sendMovement(); }}
        >W</button>
        <button 
          class="dpad-left"
          class:active={movement.left}
          on:pointerdown={() => { movement.left = true; sendMovement(); }}
          on:pointerup={() => { movement.left = false; sendMovement(); }}
        >A</button>
        <button 
          class="dpad-center"
          class:active={movement.walk}
          on:click={() => { movement.walk = !movement.walk; sendMovement(); }}
        >Walk</button>
        <button 
          class="dpad-right"
          class:active={movement.right}
          on:pointerdown={() => { movement.right = true; sendMovement(); }}
          on:pointerup={() => { movement.right = false; sendMovement(); }}
        >D</button>
        <button 
          class="dpad-down"
          class:active={movement.down}
          on:pointerdown={() => { movement.down = true; sendMovement(); }}
          on:pointerup={() => { movement.down = false; sendMovement(); }}
        >S</button>
      </div>
    </section>
    
    <!-- Target Selection -->
    <section>
      <h2>Target Selection</h2>
      <canvas 
        id="targetCanvas"
        width="800" 
        height="600"
        on:click={handleCanvasClick}
      />
    </section>
    
    <!-- Combat Controls -->
    <section>
      <h2>Combat</h2>
      <div class="button-group">
        <button 
          on:pointerdown={startShooting}
          on:pointerup={stopShooting}
          disabled={!connected}
          class:active={shooting}
        >
          🔫 Shoot
        </button>
        <label>
          <input type="checkbox" bind:checked={autoShoot} />
          Auto-fire
        </label>
      </div>
    </section>
    
    <!-- Spell Controls -->
    <section>
      <h2>Spells</h2>
      <div class="spell-slots">
        {#each [0, 1, 2, 3, 4, 5, 6, 7] as slot}
          <button 
            class:selected={selectedSpell === slot}
            on:click={() => selectedSpell = slot}
          >
            {slot + 1}
          </button>
        {/each}
      </div>
      <div class="button-group">
        <button on:click={() => castSpell(false)} disabled={!connected}>
          Cast at Target
        </button>
        <button on:click={() => castSpell(true)} disabled={!connected}>
          Self Cast
        </button>
      </div>
    </section>
    
    <!-- Macros -->
    <section>
      <h2>Macros</h2>
      <div class="button-group">
        {#each macros as macro}
          <button on:click={macro.fn} disabled={!connected}>
            {macro.name}
          </button>
        {/each}
      </div>
    </section>
    
    <!-- Recording -->
    <section>
      <h2>Recording</h2>
      <div class="button-group">
        <button on:click={toggleRecording} disabled={!connected} class:recording={isRecording}>
          {isRecording ? 'Stop Recording' : 'Start Recording'}
        </button>
        <button on:click={playRecording} disabled={!connected || recordedCommands.length === 0}>
          Play ({recordedCommands.length})
        </button>
        <button on:click={() => recordedCommands = []}>
          Clear
        </button>
      </div>
    </section>
    
    <!-- Command History -->
    <section>
      <h2>History</h2>
      <div class="history">
        {#each commandHistory as entry}
          <div class="history-entry">{entry}</div>
        {/each}
      </div>
    </section>
  </div>
</div>

<style>
  .ai-control-panel {
    font-family: 'Segoe UI', system-ui, sans-serif;
    max-width: 1200px;
    margin: 0 auto;
    padding: 20px;
    background: #0f0f23;
    color: #cccccc;
  }
  
  h1 {
    text-align: center;
    color: #00dc82;
    margin-bottom: 20px;
  }
  
  h2 {
    color: #00dc82;
    font-size: 1.2em;
    margin-bottom: 10px;
  }
  
  .status-bar {
    display: flex;
    gap: 20px;
    padding: 10px;
    background: #1a1a2e;
    border-radius: 5px;
    margin-bottom: 20px;
    font-family: monospace;
  }
  
  .status.connected {
    color: #00dc82;
  }
  
  .recording {
    color: #ff6b6b;
    animation: blink 1s infinite;
  }
  
  @keyframes blink {
    50% { opacity: 0.5; }
  }
  
  .control-sections {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
    gap: 20px;
  }
  
  section {
    background: #1a1a2e;
    padding: 15px;
    border-radius: 5px;
  }
  
  .button-group {
    display: flex;
    gap: 10px;
    flex-wrap: wrap;
  }
  
  button {
    padding: 8px 16px;
    background: #16213e;
    color: #cccccc;
    border: 1px solid #0f3460;
    border-radius: 3px;
    cursor: pointer;
    transition: all 0.2s;
  }
  
  button:hover:not(:disabled) {
    background: #0f3460;
    border-color: #00dc82;
  }
  
  button:active:not(:disabled),
  button.active {
    background: #00dc82;
    color: #0f0f23;
  }
  
  button:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }
  
  button.selected {
    background: #0f3460;
    border-color: #00dc82;
  }
  
  button.recording {
    background: #ff6b6b;
    color: white;
  }
  
  .dpad {
    display: grid;
    grid-template-areas:
      ". up ."
      "left center right"
      ". down .";
    gap: 5px;
    width: 150px;
  }
  
  .dpad-up { grid-area: up; }
  .dpad-left { grid-area: left; }
  .dpad-center { grid-area: center; }
  .dpad-right { grid-area: right; }
  .dpad-down { grid-area: down; }
  
  .spell-slots {
    display: flex;
    gap: 5px;
    margin-bottom: 10px;
  }
  
  .spell-slots button {
    width: 40px;
    height: 40px;
    padding: 0;
  }
  
  canvas {
    width: 100%;
    max-width: 400px;
    height: auto;
    aspect-ratio: 4/3;
    border: 1px solid #0f3460;
    cursor: crosshair;
    image-rendering: pixelated;
  }
  
  .history {
    background: #0f0f23;
    padding: 10px;
    border-radius: 3px;
    height: 150px;
    overflow-y: auto;
    font-family: monospace;
    font-size: 0.9em;
  }
  
  .history-entry {
    padding: 2px 0;
    border-bottom: 1px solid #1a1a2e;
  }
  
  label {
    display: flex;
    align-items: center;
    gap: 5px;
  }
  
  input[type="checkbox"] {
    width: 18px;
    height: 18px;
  }
</style>