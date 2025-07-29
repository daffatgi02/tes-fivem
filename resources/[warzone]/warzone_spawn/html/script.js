// resources/[warzone]/warzone_spawn/html/script.js

class SpawnMapUI {
  constructor() {
    this.currentLocations = {};
    this.selectedLocation = null;
    this.currentStrategy = "balanced";
    this.filters = {
      safeOnly: false,
      crewNearby: false,
      hideFullLocations: false,
    };
    this.queueStatus = null;
    this.isPreviewMode = false;

    this.init();
  }

  init() {
    this.bindEvents();
    this.setupFilters();
    this.initializeUI();
    console.log("[SPAWN MAP] UI initialized");
  }

  initializeUI() {
    // Set default strategy
    const strategySelector = document.getElementById("spawnStrategy");
    if (strategySelector) {
      strategySelector.value = this.currentStrategy;
    }

    // Initialize filter checkboxes
    Object.keys(this.filters).forEach(filterKey => {
      const checkbox = document.getElementById(filterKey);
      if (checkbox) {
        checkbox.checked = this.filters[filterKey];
      }
    });

    // Hide overlays initially
    this.hideLoading();
    this.hidePreview();
  }

  bindEvents() {
    // Close button
    document.getElementById("closeMapBtn").addEventListener("click", () => {
      this.closeMap();
    });

    // Strategy selector
    document.getElementById("spawnStrategy").addEventListener("change", (e) => {
      this.currentStrategy = e.target.value;
      this.updateStrategy();
    });

    // Filter checkboxes
    Object.keys(this.filters).forEach(filterKey => {
      const checkbox = document.getElementById(filterKey);
      if (checkbox) {
        checkbox.addEventListener("change", (e) => {
          this.filters[filterKey] = e.target.checked;
          this.applyFilters();
        });
      }
    });

    // Category filters
    document.querySelectorAll(".category-filter").forEach(button => {
      button.addEventListener("click", (e) => {
        const categoryId = e.target.dataset.category;
        this.filterLocationsByCategory(categoryId);
        
        // Update active state
        document.querySelectorAll(".category-filter").forEach(btn => 
          btn.classList.remove("active"));
        e.target.classList.add("active");
      });
    });

    // Action buttons
    document.getElementById("previewBtn").addEventListener("click", () => {
      if (this.selectedLocation) {
        this.previewLocation(this.selectedLocation);
      }
    });

    document.getElementById("spawnBtn").addEventListener("click", () => {
      if (this.selectedLocation) {
        this.confirmSpawn(this.selectedLocation);
      }
    });

    // Preview overlay buttons
    document.getElementById("confirmPreviewBtn").addEventListener("click", () => {
      this.confirmSpawn(this.selectedLocation);
    });

    document.getElementById("cancelPreviewBtn").addEventListener("click", () => {
      this.hidePreview();
      this.postMessage("stopPreview", {});
    });

    // Queue buttons
    const joinQueueBtn = document.getElementById("joinQueueBtn");
    const leaveQueueBtn = document.getElementById("leaveQueueBtn");

    if (joinQueueBtn) {
      joinQueueBtn.addEventListener("click", () => {
        if (this.selectedLocation) {
          this.joinQueue(this.selectedLocation);
        }
      });
    }

    if (leaveQueueBtn) {
      leaveQueueBtn.addEventListener("click", () => {
        this.leaveQueue();
      });
    }

    // Keyboard shortcuts
    document.addEventListener("keydown", (e) => {
      this.handleKeyboard(e);
    });

    // Message listener for game events
    window.addEventListener("message", (event) => {
      this.handleGameMessage(event.data);
    });
  }

  handleKeyboard(e) {
    switch (e.key) {
      case "Escape":
        if (this.isPreviewMode) {
          this.hidePreview();
          this.postMessage("stopPreview", {});
        } else {
          this.closeMap();
        }
        break;
      case "Enter":
        if (this.selectedLocation) {
          this.confirmSpawn(this.selectedLocation);
        }
        break;
      case "g":
      case "G":
        if (this.selectedLocation && !this.isPreviewMode) {
          this.previewLocation(this.selectedLocation);
        }
        break;
      case "q":
      case "Q":
        if (this.selectedLocation && !this.queueStatus) {
          this.joinQueue(this.selectedLocation);
        } else if (this.queueStatus) {
          this.leaveQueue();
        }
        break;
    }
  }

  handleGameMessage(data) {
    switch (data.type) {
      case 'openSpawnMap':
        this.openSpawnMap(data.data);
        break;
      case 'closeSpawnMap':
        this.closeSpawnMap();
        break;
      case 'updateSpawnData':
        this.updateSpawnData(data.data);
        break;
      case 'locationSelected':
        this.locationSelected(data);
        break;
      case 'showLocationPreview':
        this.showLocationPreview(data);
        break;
      case 'previewStarted':
        this.isPreviewMode = true;
        break;
      case 'previewStopped':
        this.isPreviewMode = false;
        this.hidePreview();
        break;
      case 'showLoading':
        this.showLoading(data.message);
        break;
      case 'hideLoading':
        this.hideLoading();
        break;
      case 'updateQueueStatus':
        this.updateQueueStatus(data.data);
        break;
      case 'hideQueueStatus':
        this.hideQueueStatus();
        break;
      case 'updateLocationStats':
        this.updateLocationStats(data.locationId, data.stats);
        break;
      case 'updateTacticalInfo':
        this.updateTacticalInfo(data.data);
        break;
      case 'showQueueOption':
        this.showQueueOption(data.data);
        break;
    }
  }

  setupFilters() {
    // Initialize filter UI components
    this.updateFilterCounts();
  }

  openSpawnMap(data) {
    document.body.style.display = 'block';
    this.currentLocations = data.locations || {};
    this.populateLocationList(data.locations);
    this.updatePlayerInfo(data.playerInfo);
    this.updateStats();
  }

  closeSpawnMap() {
    document.body.style.display = 'none';
    this.selectedLocation = null;
    this.queueStatus = null;
    this.isPreviewMode = false;
    this.hideLoading();
    this.hidePreview();
  }

  populateLocationList(locations) {
    const locationList = document.getElementById("locationList");
    if (!locationList) return;

    locationList.innerHTML = "";

    Object.entries(locations).forEach(([categoryId, category]) => {
      Object.entries(category.locations || {}).forEach(([locationId, location]) => {
        const locationCard = this.createLocationCard(locationId, location, category.label);
        locationList.appendChild(locationCard);

        // Add to map if renderer is available
        if (window.spawnMapRenderer) {
          window.spawnMapRenderer.addLocationBlip(locationId, location);
        }
      });
    });
  }

  createLocationCard(locationId, location, categoryLabel) {
    const card = document.createElement("div");
    card.className = "location-card";
    card.dataset.locationId = locationId;
    card.dataset.category = categoryLabel;
    card.dataset.safetyLevel = location.safetyLevel || 'unknown';

    const safetyClass = this.getSafetyClass(location.safetyLevel);
    const nearbyPlayers = location.nearbyPlayers || 0;
    const queueSize = location.queueSize || 0;

    card.innerHTML = `
      <div class="location-header">
        <h3 class="location-name">${location.name}</h3>
        <span class="location-category">${categoryLabel}</span>
      </div>
      <div class="location-info">
        <div class="info-row">
          <span class="info-label">Safety:</span>
          <span class="safety-indicator ${safetyClass}">${this.formatSafetyLevel(location.safetyLevel)}</span>
        </div>
        <div class="info-row">
          <span class="info-label">Players:</span>
          <span class="player-count">${nearbyPlayers}</span>
        </div>
        <div class="info-row">
          <span class="info-label">Queue:</span>
          <span class="queue-count">${queueSize}</span>
        </div>
        <div class="info-row">
          <span class="info-label">Distance:</span>
          <span class="distance">${this.calculateDistance(location.coords)}m</span>
        </div>
      </div>
      <div class="location-actions">
        <button class="action-btn small preview-btn" onclick="spawnMapUI.previewLocation('${locationId}')">
          👁️ Preview
        </button>
        <button class="action-btn small spawn-btn" onclick="spawnMapUI.selectLocation('${locationId}')">
          📍 Select
        </button>
      </div>
    `;

    // Add click handler for card selection
    card.addEventListener('click', () => {
      this.selectLocation(locationId);
    });

    return card;
  }

  selectLocation(locationId) {
    // Update visual selection
    document.querySelectorAll('.location-card').forEach(card => {
      card.classList.remove('selected');
    });

    const selectedCard = document.querySelector(`[data-location-id="${locationId}"]`);
    if (selectedCard) {
      selectedCard.classList.add('selected');
    }

    this.selectedLocation = locationId;

    // Update action buttons
    this.updateActionButtons();

    // Update map selection
    if (window.spawnMapRenderer) {
      window.spawnMapRenderer.selectBlip(locationId);
    }

    // Show location details
    this.showLocationDetails(locationId);
  }

  showLocationDetails(locationId) {
    // Find location data
    let locationData = null;
    Object.values(this.currentLocations).forEach(category => {
      if (category.locations && category.locations[locationId]) {
        locationData = category.locations[locationId];
      }
    });

    if (!locationData) return;

    // Update details panel
    const detailsPanel = document.querySelector('.location-details');
    if (detailsPanel) {
      detailsPanel.innerHTML = `
        <h3>${locationData.name}</h3>
        <div class="detail-stats">
          <div class="stat-item">
            <span class="stat-label">Coordinates:</span>
            <span class="stat-value">${Math.round(locationData.coords.x)}, ${Math.round(locationData.coords.y)}</span>
          </div>
          <div class="stat-item">
            <span class="stat-label">Elevation:</span>
            <span class="stat-value">${Math.round(locationData.coords.z)}m</span>
          </div>
          <div class="stat-item">
            <span class="stat-label">Last Activity:</span>
            <span class="stat-value">${locationData.lastActivity || 'Unknown'}</span>
          </div>
          <div class="stat-item">
            <span class="stat-label">Spawn Success:</span>
            <span class="stat-value">${locationData.successRate || 0}%</span>
          </div>
        </div>
      `;
    }
  }

  updateActionButtons() {
    const previewBtn = document.getElementById("previewBtn");
    const spawnBtn = document.getElementById("spawnBtn");

    if (this.selectedLocation) {
      previewBtn.disabled = false;
      spawnBtn.disabled = false;
      previewBtn.textContent = "👁️ Preview Location";
      spawnBtn.textContent = "🚁 Deploy Here";
    } else {
      previewBtn.disabled = true;
      spawnBtn.disabled = true;
      previewBtn.textContent = "👁️ Select Location";
      spawnBtn.textContent = "🚁 Select Location";
    }
  }

  applyFilters() {
    const cards = document.querySelectorAll('.location-card');

    cards.forEach(card => {
      let showCard = true;

      // Safe only filter
      if (this.filters.safeOnly) {
        const safetyLevel = card.dataset.safetyLevel;
        if (!['very_safe', 'safe'].includes(safetyLevel)) {
          showCard = false;
        }
      }

      // Hide full locations filter
      if (this.filters.hideFullLocations) {
        const queueCount = parseInt(card.querySelector('.queue-count').textContent) || 0;
        if (queueCount > 5) {
          showCard = false;
        }
      }

      card.style.display = showCard ? 'block' : 'none';
    });

    this.updateStats();
    this.updateFilterCounts();
  }

  filterLocationsByCategory(categoryId) {
    const cards = document.querySelectorAll('.location-card');

    if (categoryId === 'all') {
      cards.forEach(card => card.style.display = 'block');
    } else {
      const category = this.currentLocations[categoryId];
      const categoryLabel = category ? category.label : '';

      cards.forEach(card => {
        card.style.display = card.dataset.category === categoryLabel ? 'block' : 'none';
      });
    }

    this.updateStats();
  }

  updateStats() {
    const visibleCards = document.querySelectorAll('.location-card[style*="block"], .location-card:not([style])');
    const availableCount = visibleCards.length;

    // Calculate crew count
    const crewCount = this.calculateCrewNearby();

    // Get zone activity
    const zoneActivity = this.getCurrentZoneActivity();

    // Update UI elements
    this.updateElement('availableCount', availableCount);
    this.updateElement('crewCount', crewCount);
    this.updateElement('zoneActivity', zoneActivity);
  }

  updateStrategy() {
    const strategyColors = {
      safe: '#4CAF50',
      balanced: '#FF9800',
      aggressive: '#F44336',
    };

    const selector = document.getElementById('spawnStrategy');
    if (selector) {
      selector.style.borderColor = strategyColors[this.currentStrategy];
    }

    // Notify game
    this.postMessage('updateStrategy', { strategy: this.currentStrategy });
  }

  previewLocation(locationId) {
    if (!locationId) locationId = this.selectedLocation;
    if (!locationId) return;

    this.showPreview();
    this.postMessage('previewLocation', { locationId });
  }

  confirmSpawn(locationId) {
    if (!locationId) locationId = this.selectedLocation;
    if (!locationId) return;

    this.showLoading('Processing spawn request...');
    this.postMessage('confirmSpawn', {
      locationId,
      strategy: this.currentStrategy,
    });
  }

  joinQueue(locationId) {
    if (!locationId) locationId = this.selectedLocation;
    if (!locationId) return;

    this.postMessage('joinQueue', { locationId });
  }

  leaveQueue() {
    this.postMessage('leaveQueue', {});
  }

  showLoading(message = 'Loading...') {
    const loadingOverlay = document.getElementById('loadingOverlay');
    if (loadingOverlay) {
      loadingOverlay.style.display = 'flex';
      const loadingText = loadingOverlay.querySelector('p');
      if (loadingText) {
        loadingText.textContent = message;
      }
    }
  }

  hideLoading() {
    const loadingOverlay = document.getElementById('loadingOverlay');
    if (loadingOverlay) {
      loadingOverlay.style.display = 'none';
    }
  }

  showPreview() {
    const previewOverlay = document.getElementById('previewOverlay');
    if (previewOverlay) {
      previewOverlay.style.display = 'block';
      this.isPreviewMode = true;
    }
  }

  hidePreview() {
    const previewOverlay = document.getElementById('previewOverlay');
    if (previewOverlay) {
      previewOverlay.style.display = 'none';
      this.isPreviewMode = false;
    }
  }

  updateQueueStatus(queueData) {
    this.queueStatus = queueData;

    // Update queue UI elements
    const queueInfo = document.getElementById('queueInfo');
    if (queueInfo) {
      queueInfo.innerHTML = `
        <div class="queue-status">
          <h4>🕐 In Queue</h4>
          <p>Position: ${queueData.position}/${queueData.queueSize}</p>
          <p>Estimated wait: ${queueData.estimatedWait}s</p>
          <button id="leaveQueueBtn" class="action-btn cancel">Leave Queue</button>
        </div>
      `;
      queueInfo.style.display = 'block';
    }
  }

  hideQueueStatus() {
    this.queueStatus = null;
    const queueInfo = document.getElementById('queueInfo');
    if (queueInfo) {
      queueInfo.style.display = 'none';
    }
  }

  // Utility methods
  calculateDistance(coords) {
    // Placeholder - you can implement actual distance calculation
    return Math.floor(Math.random() * 1000) + 100;
  }

  calculateCrewNearby() {
    // Placeholder - integrate with crew system
    return Math.floor(Math.random() * 5);
  }

  getCurrentZoneActivity() {
    const activities = ['Low', 'Normal', 'High', 'Extreme'];
    return activities[Math.floor(Math.random() * activities.length)];
  }

  getSafetyClass(safetyLevel) {
    const classes = {
      'very_safe': 'safety-very-safe',
      'safe': 'safety-safe',
      'moderate': 'safety-moderate',
      'dangerous': 'safety-dangerous',
      'very_dangerous': 'safety-very-dangerous'
    };
    return classes[safetyLevel] || 'safety-unknown';
  }

  formatSafetyLevel(level) {
    const formatted = {
      'very_safe': 'Very Safe',
      'safe': 'Safe',
      'moderate': 'Moderate',
      'dangerous': 'Dangerous',
      'very_dangerous': 'Very Dangerous'
    };
    return formatted[level] || 'Unknown';
  }

  updateElement(id, value) {
    const element = document.getElementById(id);
    if (element) {
      element.textContent = value;
    }
  }

  updateFilterCounts() {
    // Update filter button counts
    Object.keys(this.filters).forEach(filterKey => {
      const button = document.querySelector(`[data-filter="${filterKey}"]`);
      if (button) {
        const count = this.getFilterCount(filterKey);
        button.querySelector('.filter-count').textContent = count;
      }
    });
  }

  getFilterCount(filterKey) {
    // Calculate how many locations match this filter
    const cards = document.querySelectorAll('.location-card');
    let count = 0;

    cards.forEach(card => {
      let matches = false;

      switch (filterKey) {
        case 'safeOnly':
          matches = ['very_safe', 'safe'].includes(card.dataset.safetyLevel);
          break;
        case 'crewNearby':
          // Implement crew nearby logic
          matches = Math.random() > 0.7; // Placeholder
          break;
        case 'hideFullLocations':
          const queueCount = parseInt(card.querySelector('.queue-count').textContent) || 0;
          matches = queueCount <= 5;
          break;
      }

      if (matches) count++;
    });

    return count;
  }

  postMessage(type, data = {}) {
    fetch(`https://${window.GetParentResourceName()}/${type}`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(data),
    }).catch(error => {
      console.error('[SPAWN MAP] PostMessage error:', error);
    });
  }

  closeMap() {
    this.postMessage('closeMap', {});
  }
}

// Initialize UI when DOM is loaded
let spawnMapUI = null;

document.addEventListener('DOMContentLoaded', () => {
  spawnMapUI = new SpawnMapUI();
  window.spawnMapUI = spawnMapUI;
});

// Handle resource restart
window.addEventListener('beforeunload', () => {
  if (spawnMapUI) {
    spawnMapUI.closeMap();
  }
});