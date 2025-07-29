// resources/[warzone]/warzone_spawn/html/map.js

class SpawnMapRenderer {
  constructor() {
    this.mapContainer = null;
    this.mapBlips = new Map();
    this.selectedBlip = null;
    this.mapBounds = {
      minX: -4000,
      maxX: 4000,
      minY: -4000,
      maxY: 4000
    };
    this.mapScale = 1.0;
    this.mapOffset = { x: 0, y: 0 };
    this.isDragging = false;
    this.lastMousePos = { x: 0, y: 0 };
    
    this.init();
  }

  init() {
    this.createMapContainer();
    this.bindMapEvents();
    this.loadMapBackground();
    console.log("[SPAWN MAP] Map renderer initialized");
  }

  createMapContainer() {
    this.mapContainer = document.getElementById('mapContainer');
    if (!this.mapContainer) {
      this.mapContainer = document.createElement('div');
      this.mapContainer.id = 'mapContainer';
      this.mapContainer.className = 'map-container';
      document.body.appendChild(this.mapContainer);
    }

    // Apply initial map styles
    this.mapContainer.style.cssText = `
      position: relative;
      width: 100%;
      height: 100%;
      background: #1a1a1a;
      overflow: hidden;
      cursor: grab;
      background-image: url('https://i.imgur.com/YjL5aOB.jpg');
      background-size: cover;
      background-position: center;
      background-repeat: no-repeat;
    `;
  }

  loadMapBackground() {
    // Create map overlay for better visibility
    const overlay = document.createElement('div');
    overlay.className = 'map-overlay';
    overlay.style.cssText = `
      position: absolute;
      top: 0;
      left: 0;
      width: 100%;
      height: 100%;
      background: rgba(0, 0, 0, 0.3);
      pointer-events: none;
    `;
    this.mapContainer.appendChild(overlay);

    // Add grid lines
    this.createMapGrid();
  }

  createMapGrid() {
    const gridContainer = document.createElement('div');
    gridContainer.className = 'map-grid';
    gridContainer.style.cssText = `
      position: absolute;
      top: 0;
      left: 0;
      width: 100%;
      height: 100%;
      pointer-events: none;
      opacity: 0.1;
    `;

    // Create grid lines
    for (let i = 0; i <= 10; i++) {
      // Vertical lines
      const vLine = document.createElement('div');
      vLine.style.cssText = `
        position: absolute;
        left: ${i * 10}%;
        top: 0;
        width: 1px;
        height: 100%;
        background: #fff;
      `;
      gridContainer.appendChild(vLine);

      // Horizontal lines
      const hLine = document.createElement('div');
      hLine.style.cssText = `
        position: absolute;
        top: ${i * 10}%;
        left: 0;
        width: 100%;
        height: 1px;
        background: #fff;
      `;
      gridContainer.appendChild(hLine);
    }

    this.mapContainer.appendChild(gridContainer);
  }

  bindMapEvents() {
    // Mouse wheel zoom
    this.mapContainer.addEventListener('wheel', (e) => {
      e.preventDefault();
      this.handleZoom(e);
    });

    // Mouse drag
    this.mapContainer.addEventListener('mousedown', (e) => {
      this.startDrag(e);
    });

    document.addEventListener('mousemove', (e) => {
      this.handleDrag(e);
    });

    document.addEventListener('mouseup', () => {
      this.stopDrag();
    });

    // Touch events for mobile
    this.mapContainer.addEventListener('touchstart', (e) => {
      this.startDrag(e.touches[0]);
    });

    this.mapContainer.addEventListener('touchmove', (e) => {
      e.preventDefault();
      this.handleDrag(e.touches[0]);
    });

    this.mapContainer.addEventListener('touchend', () => {
      this.stopDrag();
    });
  }

  handleZoom(e) {
    const zoomFactor = e.deltaY > 0 ? 0.9 : 1.1;
    this.mapScale = Math.max(0.5, Math.min(3.0, this.mapScale * zoomFactor));
    
    this.updateMapTransform();
    this.updateBlipScale();
  }

  startDrag(e) {
    this.isDragging = true;
    this.lastMousePos = { x: e.clientX, y: e.clientY };
    this.mapContainer.style.cursor = 'grabbing';
  }

  handleDrag(e) {
    if (!this.isDragging) return;

    const deltaX = e.clientX - this.lastMousePos.x;
    const deltaY = e.clientY - this.lastMousePos.y;

    this.mapOffset.x += deltaX;
    this.mapOffset.y += deltaY;

    this.lastMousePos = { x: e.clientX, y: e.clientY };
    this.updateMapTransform();
  }

  stopDrag() {
    this.isDragging = false;
    this.mapContainer.style.cursor = 'grab';
  }

  updateMapTransform() {
    const transform = `translate(${this.mapOffset.x}px, ${this.mapOffset.y}px) scale(${this.mapScale})`;
    
    // Apply transform to all map elements
    const mapElements = this.mapContainer.querySelectorAll('.map-element');
    mapElements.forEach(element => {
      element.style.transform = transform;
    });
  }

  updateBlipScale() {
    this.mapBlips.forEach(blip => {
      const baseSize = blip.isSelected ? 24 : 16;
      const scaledSize = baseSize / this.mapScale;
      blip.element.style.width = `${scaledSize}px`;
      blip.element.style.height = `${scaledSize}px`;
    });
  }

  // Convert game coordinates to map coordinates
  gameToMapCoords(gameX, gameY) {
    const mapWidth = this.mapContainer.clientWidth;
    const mapHeight = this.mapContainer.clientHeight;
    
    const normalizedX = (gameX - this.mapBounds.minX) / (this.mapBounds.maxX - this.mapBounds.minX);
    const normalizedY = (gameY - this.mapBounds.minY) / (this.mapBounds.maxY - this.mapBounds.minY);
    
    return {
      x: normalizedX * mapWidth,
      y: (1 - normalizedY) * mapHeight // Invert Y for screen coordinates
    };
  }

  // Convert map coordinates to game coordinates
  mapToGameCoords(mapX, mapY) {
    const mapWidth = this.mapContainer.clientWidth;
    const mapHeight = this.mapContainer.clientHeight;
    
    const normalizedX = mapX / mapWidth;
    const normalizedY = 1 - (mapY / mapHeight); // Invert Y
    
    return {
      x: this.mapBounds.minX + normalizedX * (this.mapBounds.maxX - this.mapBounds.minX),
      y: this.mapBounds.minY + normalizedY * (this.mapBounds.maxY - this.mapBounds.minY)
    };
  }

  addLocationBlip(locationId, locationData) {
    const mapCoords = this.gameToMapCoords(locationData.coords.x, locationData.coords.y);
    
    const blipElement = document.createElement('div');
    blipElement.className = 'location-blip map-element';
    blipElement.id = `blip-${locationId}`;
    
    // Style the blip based on location properties
    const blipColor = this.getBlipColor(locationData.category, locationData.safetyLevel);
    const blipSize = locationData.priority === 'high' ? 20 : 16;
    
    blipElement.style.cssText = `
      position: absolute;
      left: ${mapCoords.x - blipSize/2}px;
      top: ${mapCoords.y - blipSize/2}px;
      width: ${blipSize}px;
      height: ${blipSize}px;
      background: ${blipColor};
      border: 2px solid rgba(255, 255, 255, 0.8);
      border-radius: 50%;
      cursor: pointer;
      transition: all 0.3s ease;
      z-index: 100;
      box-shadow: 0 0 10px rgba(0, 0, 0, 0.5);
    `;

    // Add hover effects
    blipElement.addEventListener('mouseenter', () => {
      this.showBlipTooltip(blipElement, locationData);
      blipElement.style.transform = 'scale(1.2)';
      blipElement.style.zIndex = '110';
    });

    blipElement.addEventListener('mouseleave', () => {
      this.hideBlipTooltip();
      blipElement.style.transform = 'scale(1.0)';
      blipElement.style.zIndex = '100';
    });

    // Add click handler
    blipElement.addEventListener('click', (e) => {
      e.stopPropagation();
      this.selectBlip(locationId, blipElement);
    });

    // Add pulsing animation for active locations
    if (locationData.isActive) {
      blipElement.style.animation = 'pulse 2s infinite';
    }

    this.mapContainer.appendChild(blipElement);
    
    // Store blip reference
    this.mapBlips.set(locationId, {
      element: blipElement,
      locationData: locationData,
      isSelected: false
    });

    console.log(`[MAP] Added blip for location: ${locationId}`);
  }

  getBlipColor(category, safetyLevel) {
    const categoryColors = {
      'urban': '#2196F3',      // Blue
      'industrial': '#FF9800', // Orange
      'military': '#F44336',   // Red
      'remote': '#4CAF50'      // Green
    };

    const safetyColors = {
      'very_safe': '#4CAF50',   // Green
      'safe': '#8BC34A',       // Light Green
      'moderate': '#FFC107',   // Yellow
      'dangerous': '#FF5722',  // Red-Orange
      'very_dangerous': '#F44336' // Red
    };

    // Prioritize safety level over category
    return safetyColors[safetyLevel] || categoryColors[category] || '#9E9E9E';
  }

  selectBlip(locationId, blipElement) {
    // Deselect previous blip
    if (this.selectedBlip) {
      const prevBlip = this.mapBlips.get(this.selectedBlip);
      if (prevBlip) {
        prevBlip.element.style.borderColor = 'rgba(255, 255, 255, 0.8)';
        prevBlip.element.style.borderWidth = '2px';
        prevBlip.isSelected = false;
      }
    }

    // Select new blip
    this.selectedBlip = locationId;
    const blip = this.mapBlips.get(locationId);
    if (blip) {
      blipElement.style.borderColor = '#FFD700';
      blipElement.style.borderWidth = '3px';
      blipElement.style.boxShadow = '0 0 20px rgba(255, 215, 0, 0.8)';
      blip.isSelected = true;
    }

    // Notify parent about selection
    if (window.spawnMapUI) {
      window.spawnMapUI.locationSelected({
        locationId: locationId,
        locationData: blip ? blip.locationData : null
      });
    }

    console.log(`[MAP] Selected location: ${locationId}`);
  }

  showBlipTooltip(blipElement, locationData) {
    const tooltip = document.createElement('div');
    tooltip.className = 'blip-tooltip';
    tooltip.innerHTML = `
      <div class="tooltip-header">${locationData.name}</div>
      <div class="tooltip-content">
        <div>Category: ${locationData.category}</div>
        <div>Safety: ${locationData.safetyLevel || 'Unknown'}</div>
        <div>Players: ${locationData.nearbyPlayers || 0}</div>
      </div>
    `;

    tooltip.style.cssText = `
      position: absolute;
      background: rgba(0, 0, 0, 0.9);
      color: white;
      padding: 8px 12px;
      border-radius: 4px;
      font-size: 12px;
      pointer-events: none;
      z-index: 1000;
      min-width: 150px;
      box-shadow: 0 2px 10px rgba(0, 0, 0, 0.5);
    `;

    // Position tooltip
    const rect = blipElement.getBoundingClientRect();
    tooltip.style.left = `${rect.right + 10}px`;
    tooltip.style.top = `${rect.top}px`;

    document.body.appendChild(tooltip);
    this.currentTooltip = tooltip;
  }

  hideBlipTooltip() {
    if (this.currentTooltip) {
      this.currentTooltip.remove();
      this.currentTooltip = null;
    }
  }

  updateBlipData(locationId, newData) {
    const blip = this.mapBlips.get(locationId);
    if (blip) {
      blip.locationData = { ...blip.locationData, ...newData };
      
      // Update blip appearance if needed
      const newColor = this.getBlipColor(blip.locationData.category, blip.locationData.safetyLevel);
      blip.element.style.background = newColor;
      
      // Update animation
      if (newData.isActive) {
        blip.element.style.animation = 'pulse 2s infinite';
      } else {
        blip.element.style.animation = 'none';
      }
    }
  }

  removeBlip(locationId) {
    const blip = this.mapBlips.get(locationId);
    if (blip) {
      blip.element.remove();
      this.mapBlips.delete(locationId);
      
      if (this.selectedBlip === locationId) {
        this.selectedBlip = null;
      }
    }
  }

  clearAllBlips() {
    this.mapBlips.forEach((blip, locationId) => {
      blip.element.remove();
    });
    this.mapBlips.clear();
    this.selectedBlip = null;
  }

  centerOnLocation(locationId) {
    const blip = this.mapBlips.get(locationId);
    if (blip) {
      const rect = blip.element.getBoundingClientRect();
      const containerRect = this.mapContainer.getBoundingClientRect();
      
      const centerX = containerRect.width / 2;
      const centerY = containerRect.height / 2;
      
      this.mapOffset.x = centerX - (rect.left - containerRect.left);
      this.mapOffset.y = centerY - (rect.top - containerRect.top);
      
      this.updateMapTransform();
    }
  }

  setMapBounds(minX, maxX, minY, maxY) {
    this.mapBounds = { minX, maxX, minY, maxY };
  }

  destroy() {
    this.clearAllBlips();
    this.hideBlipTooltip();
    
    if (this.mapContainer) {
      this.mapContainer.remove();
    }
  }
}

// Add CSS animations
const style = document.createElement('style');
style.textContent = `
  @keyframes pulse {
    0% { box-shadow: 0 0 10px rgba(0, 0, 0, 0.5); }
    50% { box-shadow: 0 0 20px rgba(255, 255, 255, 0.8); }
    100% { box-shadow: 0 0 10px rgba(0, 0, 0, 0.5); }
  }

  .blip-tooltip .tooltip-header {
    font-weight: bold;
    margin-bottom: 4px;
    color: #FFD700;
  }

  .blip-tooltip .tooltip-content div {
    margin: 2px 0;
  }

  .map-container::-webkit-scrollbar {
    display: none;
  }
`;
document.head.appendChild(style);

// Initialize map renderer when DOM is loaded
let spawnMapRenderer = null;

document.addEventListener('DOMContentLoaded', () => {
  spawnMapRenderer = new SpawnMapRenderer();
  window.spawnMapRenderer = spawnMapRenderer;
});