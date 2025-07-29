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

    this.init();
  }

  init() {
    this.bindEvents();
    this.setupFilters();
    console.log("[SPAWN MAP] UI initialized");
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
    document
      .getElementById("confirmPreviewBtn")
      .addEventListener("click", () => {
        this.confirmSpawn(this.selectedLocation);
      });

    document
      .getElementById("cancelPreviewBtn")
      .addEventListener("click", () => {
        this.hidePreview();
      });

    // Keyboard shortcuts
    document.addEventListener("keydown", (e) => {
      switch (e.key) {
        case "Escape":
          this.closeMap();
          break;
        case "Enter":
          if (this.selectedLocation) {
            this.confirmSpawn(this.selectedLocation);
          }
          break;
        case "g":
        case "G":
          if (this.selectedLocation) {
            this.previewLocation(this.selectedLocation);
          }
          break;
      }
    });
  }

  setupFilters() {
    // Filter checkboxes
    document.getElementById("showSafeOnly").addEventListener("change", (e) => {
      this.filters.safeOnly = e.target.checked;
      this.filterLocations();
    });

    document
      .getElementById("showCrewNearby")
      .addEventListener("change", (e) => {
        this.filters.crewNearby = e.target.checked;
        this.filterLocations();
      });

    document
      .getElementById("hideFullLocations")
      .addEventListener("change", (e) => {
        this.filters.hideFullLocations = e.target.checked;
        this.filterLocations();
      });
  }

  showMap(data) {
    document.getElementById("spawnMap").style.display = "block";
    document.getElementById("spawnMap").classList.add("fade-in");

    this.currentLocations = data.locations;
    this.playerData = data.playerData;

    this.renderCategories();
    this.renderLocations();
    this.updateStats();
  }

  hideMap() {
    document.getElementById("spawnMap").style.display = "none";
    this.selectedLocation = null;
    this.hideLocationDetails();
  }

  renderCategories() {
    const categoriesList = document.getElementById("categoriesList");
    categoriesList.innerHTML = "";

    for (const [categoryId, category] of Object.entries(
      this.currentLocations
    )) {
      const categoryElement = this.createCategoryElement(categoryId, category);
      categoriesList.appendChild(categoryElement);
    }
  }

  createCategoryElement(categoryId, category) {
    const categoryDiv = document.createElement("div");
    categoryDiv.className = "category-item";
    categoryDiv.dataset.category = categoryId;

    const locationCount = Object.keys(category.locations).length;

    categoryDiv.innerHTML = `
            <div class="category-icon">${category.icon}</div>
            <div class="category-info">
                <h4>${category.label}</h4>
                <span>${locationCount} locations</span>
            </div>
        `;

    categoryDiv.addEventListener("click", () => {
      this.selectCategory(categoryId);
    });

    return categoryDiv;
  }

  selectCategory(categoryId) {
    // Update category selection
    document.querySelectorAll(".category-item").forEach((item) => {
      item.classList.remove("active");
    });
    document
      .querySelector(`[data-category="${categoryId}"]`)
      .classList.add("active");

    // Filter locations by category
    this.filterLocationsByCategory(categoryId);
  }

  renderLocations() {
    const locationsList = document.getElementById("locationsList");
    locationsList.innerHTML = "";

    for (const [categoryId, category] of Object.entries(
      this.currentLocations
    )) {
      for (const [locationId, location] of Object.entries(category.locations)) {
        const locationElement = this.createLocationElement(
          locationId,
          location,
          category
        );
        locationsList.appendChild(locationElement);
      }
    }
  }

  createLocationElement(locationId, location, category) {
    const locationDiv = document.createElement("div");
    locationDiv.className = "location-card";
    locationDiv.dataset.locationId = locationId;
    locationDiv.dataset.category = category.label;

    // Calculate current capacity (simulate for demo)
    const currentCapacity = Math.floor(Math.random() * location.maxCapacity);
    const capacityPercentage = (currentCapacity / location.maxCapacity) * 100;

    // Generate risk dots
    const riskDots = Array.from(
      { length: 5 },
      (_, i) =>
        `<div class="risk-dot ${i < location.riskLevel ? "active" : ""}"></div>`
    ).join("");

    locationDiv.innerHTML = `
           <div class="location-header">
               <div class="location-name">${location.name}</div>
               <div class="risk-level">${riskDots}</div>
           </div>
           <div class="location-description">${location.description}</div>
           <div class="location-stats">
               <div class="location-capacity">
                   <span>👥 ${currentCapacity}/${location.maxCapacity}</span>
                   <div class="capacity-bar">
                       <div class="capacity-fill" style="width: ${capacityPercentage}%"></div>
                   </div>
               </div>
               <div class="location-roles">
                   🎖️ ${
                     location.recommendedRoles
                       ? location.recommendedRoles.length
                       : 0
                   } roles
               </div>
           </div>
       `;

    // Add selection handler
    locationDiv.addEventListener("click", () => {
      this.selectLocation(locationId, location);
    });

    return locationDiv;
  }

  selectLocation(locationId, location) {
    this.selectedLocation = locationId;

    // Update visual selection
    document.querySelectorAll(".location-card").forEach((card) => {
      card.classList.remove("selected", "pulse");
    });

    const selectedCard = document.querySelector(
      `[data-location-id="${locationId}"]`
    );
    if (selectedCard) {
      selectedCard.classList.add("selected", "pulse");
    }

    // Show location details
    this.showLocationDetails(locationId, location);

    // Notify game
    this.postMessage("selectLocation", { locationId });
  }

  showLocationDetails(locationId, location) {
    const detailsPanel = document.getElementById("locationDetails");

    // Update location name and description
    document.getElementById("locationName").textContent = location.name;
    document.getElementById("locationDescription").textContent =
      location.description;

    // Update risk bars
    this.updateRiskBars(location.riskLevel || 1);

    // Update advantages list
    this.updateAdvantagesList(location.advantages || []);

    // Update disadvantages list
    this.updateDisadvantagesList(location.disadvantages || []);

    // Update recommended roles
    this.updateRecommendedRoles(location.recommendedRoles || []);

    // Update location stats
    this.updateLocationStats(location);

    // Show details panel
    detailsPanel.style.display = "block";
    detailsPanel.classList.add("slide-up");
  }

  hideLocationDetails() {
    document.getElementById("locationDetails").style.display = "none";
  }

  updateRiskBars(riskLevel) {
    const riskBars = document.getElementById("riskBars");
    riskBars.innerHTML = "";

    for (let i = 1; i <= 5; i++) {
      const bar = document.createElement("div");
      bar.className = `risk-bar ${i <= riskLevel ? "filled" : ""}`;
      riskBars.appendChild(bar);
    }
  }

  updateAdvantagesList(advantages) {
    const list = document.getElementById("advantagesList");
    list.innerHTML = "";

    advantages.forEach((advantage) => {
      const li = document.createElement("li");
      li.textContent = advantage;
      list.appendChild(li);
    });

    if (advantages.length === 0) {
      list.innerHTML = "<li>No specific advantages listed</li>";
    }
  }

  updateDisadvantagesList(disadvantages) {
    const list = document.getElementById("disadvantagesList");
    list.innerHTML = "";

    disadvantages.forEach((disadvantage) => {
      const li = document.createElement("li");
      li.textContent = disadvantage;
      list.appendChild(li);
    });

    if (disadvantages.length === 0) {
      list.innerHTML = "<li>No significant disadvantages</li>";
    }
  }

  updateRecommendedRoles(roles) {
    const container = document.getElementById("recommendedRoles");
    container.innerHTML = "";

    if (roles.length === 0) {
      container.innerHTML = '<span class="role-tag">All Roles</span>';
      return;
    }

    roles.forEach((role) => {
      const tag = document.createElement("span");
      tag.className = "role-tag";
      tag.textContent = this.capitalizeRole(role);
      container.appendChild(tag);
    });
  }

  updateLocationStats(location) {
    // Simulate real-time stats (in real implementation, get from server)
    const currentCapacity = Math.floor(Math.random() * location.maxCapacity);
    const successRate = Math.floor(Math.random() * 40) + 60; // 60-100%
    const avgSurvival = Math.floor(Math.random() * 10) + 5; // 5-15 minutes

    document.getElementById(
      "locationCapacity"
    ).textContent = `${currentCapacity}/${location.maxCapacity}`;
    document.getElementById("successRate").textContent = `${successRate}%`;
    document.getElementById("avgSurvival").textContent = `${avgSurvival}m`;
  }

  filterLocations() {
    const locationCards = document.querySelectorAll(".location-card");

    locationCards.forEach((card) => {
      let visible = true;
      const locationId = card.dataset.locationId;

      // Apply filters
      if (this.filters.safeOnly) {
        const riskDots = card.querySelectorAll(".risk-dot.active").length;
        if (riskDots > 2) visible = false;
      }

      if (this.filters.hideFullLocations) {
        const capacityText = card.querySelector(
          ".location-capacity span"
        ).textContent;
        const [current, max] = capacityText.match(/\d+/g).map(Number);
        if (current >= max) visible = false;
      }

      // Show/hide card
      card.style.display = visible ? "block" : "none";
    });

    this.updateStats();
  }

  filterLocationsByCategory(categoryId) {
    const locationCards = document.querySelectorAll(".location-card");

    if (categoryId === "all") {
      locationCards.forEach((card) => (card.style.display = "block"));
    } else {
      const category = this.currentLocations[categoryId];
      const categoryLabel = category ? category.label : "";

      locationCards.forEach((card) => {
        card.style.display =
          card.dataset.category === categoryLabel ? "block" : "none";
      });
    }

    this.updateStats();
  }

  updateStats() {
    const visibleCards = document.querySelectorAll(
      '.location-card[style*="block"], .location-card:not([style])'
    );
    const availableCount = visibleCards.length;

    // Simulate crew count
    const crewCount = Math.floor(Math.random() * 5);

    // Simulate zone activity
    const activities = ["Low", "Normal", "High", "Extreme"];
    const zoneActivity =
      activities[Math.floor(Math.random() * activities.length)];

    document.getElementById("availableCount").textContent = availableCount;
    document.getElementById("crewCount").textContent = crewCount;
    document.getElementById("zoneActivity").textContent = zoneActivity;
  }

  updateStrategy() {
    // Update UI to reflect strategy change
    const strategyColors = {
      safe: "#4CAF50",
      balanced: "#FF9800",
      aggressive: "#F44336",
    };

    const selector = document.getElementById("spawnStrategy");
    selector.style.borderColor = strategyColors[this.currentStrategy];

    // Notify game
    this.postMessage("updateStrategy", { strategy: this.currentStrategy });
  }

  previewLocation(locationId) {
    this.showPreview();
    this.postMessage("previewLocation", { locationId });
  }

  confirmSpawn(locationId) {
    this.showLoading();
    this.postMessage("confirmSpawn", {
      locationId,
      strategy: this.currentStrategy,
    });
  }

  showLoading() {
    document.getElementById("loadingOverlay").style.display = "flex";
  }

  hideLoading() {
    document.getElementById("loadingOverlay").style.display = "none";
  }

  showPreview() {
    document.getElementById("previewOverlay").style.display = "block";
  }

  hidePreview() {
    document.getElementById("previewOverlay").style.display = "none";
  }

  locationSelected(data) {
    // Handle location selection from game
    if (data.locationData) {
      this.showLocationDetails(data.locationId, data.locationData);
    }
  }

  showLocationPreview(data) {
    this.showPreview();
    document.getElementById(
      "previewInfo"
    ).textContent = `Previewing ${data.locationData.name} - Use camera controls to look around`;
  }

  closeMap() {
    this.postMessage("closeMap", {});
  }

  // Utility methods
  capitalizeRole(role) {
    return role.charAt(0).toUpperCase() + role.slice(1);
  }

  postMessage(type, data) {
    fetch(`https://${GetParentResourceName()}/${type}`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify(data),
    }).catch((error) => {
      console.error("Failed to send message:", error);
    });
  }

  // Handle escape key globally
  handleEscape() {
    this.closeMap();
  }
}

// Initialize UI
const spawnMapUI = new SpawnMapUI();

// Message handlers from game
window.addEventListener("message", (event) => {
  const data = event.data;

  switch (data.type) {
    case "showSpawnMap":
      spawnMapUI.showMap(data);
      break;
    case "hideSpawnMap":
      spawnMapUI.hideMap();
      break;
    case "locationSelected":
      spawnMapUI.locationSelected(data);
      break;
    case "showLocationPreview":
      spawnMapUI.showLocationPreview(data);
      break;
    case "hideLoading":
      spawnMapUI.hideLoading();
      break;
    case "hidePreview":
      spawnMapUI.hidePreview();
      break;
  }
});

// Handle resource unload
window.addEventListener("beforeunload", () => {
  spawnMapUI.closeMap();
});
