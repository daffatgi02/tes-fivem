document.addEventListener('DOMContentLoaded', function() {
    const setupUI = document.getElementById('setupUI');
    const gameUI = document.getElementById('gameUI');
    const startBtn = document.getElementById('startBtn');
    const closeBtn = document.getElementById('closeBtn');
    const stopGameBtn = document.getElementById('stopGameBtn');
    const enemyCounter = document.getElementById('enemyCounter');
    const selectedCount = document.getElementById('selectedCount');
    const weaponList = document.getElementById('weaponList');
    
    let availableWeapons = [];
    let selectedWeapons = [];
    let currentCategory = 'all';

    // Tab switching
    document.querySelectorAll('.tab-btn').forEach(btn => {
        btn.addEventListener('click', function() {
            const targetTab = this.getAttribute('data-tab');
            switchTab(targetTab);
        });
    });

    // Category filtering
    document.querySelectorAll('.filter-btn').forEach(btn => {
        btn.addEventListener('click', function() {
            document.querySelectorAll('.filter-btn').forEach(b => b.classList.remove('active'));
            this.classList.add('active');
            currentCategory = this.getAttribute('data-category');
            renderWeapons();
        });
    });

    function switchTab(tabName) {
        // Switch tab buttons
        document.querySelectorAll('.tab-btn').forEach(btn => {
            btn.classList.remove('active');
        });
        document.querySelector(`[data-tab="${tabName}"]`).classList.add('active');

        // Switch tab content
        document.querySelectorAll('.tab-content').forEach(content => {
            content.classList.remove('active');
        });
        document.getElementById(`${tabName}-tab`).classList.add('active');
    }

    function renderWeapons() {
        weaponList.innerHTML = '';
        
        const filteredWeapons = currentCategory === 'all' 
            ? availableWeapons 
            : availableWeapons.filter(weapon => weapon.category === currentCategory);

        filteredWeapons.forEach(weapon => {
            const weaponItem = document.createElement('div');
            weaponItem.className = 'weapon-item';
            weaponItem.setAttribute('data-hash', weapon.hash);
            
            if (selectedWeapons.includes(weapon.hash)) {
                weaponItem.classList.add('selected');
            }
            
            if (selectedWeapons.length >= 2 && !selectedWeapons.includes(weapon.hash)) {
                weaponItem.classList.add('disabled');
            }

            weaponItem.innerHTML = `
                <div class="weapon-name">${weapon.name}</div>
                <div class="weapon-category">${weapon.category}</div>
                <div class="weapon-ammo">Ammo: ${weapon.ammo}</div>
            `;

            weaponItem.addEventListener('click', function() {
                if (this.classList.contains('disabled')) return;
                
                const weaponHash = parseInt(this.getAttribute('data-hash'));
                toggleWeaponSelection(weaponHash);
            });

            weaponList.appendChild(weaponItem);
        });
    }

    function toggleWeaponSelection(weaponHash) {
        const index = selectedWeapons.indexOf(weaponHash);
        
        if (index > -1) {
            // Deselect weapon
            selectedWeapons.splice(index, 1);
        } else {
            // Select weapon (if less than 2 selected)
            if (selectedWeapons.length < 2) {
                selectedWeapons.push(weaponHash);
            }
        }
        
        updateSelectedCount();
        renderWeapons();
        updateStartButton();
    }

    function updateSelectedCount() {
        selectedCount.textContent = selectedWeapons.length;
        
        if (selectedWeapons.length === 2) {
            selectedCount.style.color = '#4CAF50';
        } else {
            selectedCount.style.color = '#ff6b6b';
        }
    }

    function updateStartButton() {
        if (selectedWeapons.length === 2) {
            startBtn.disabled = false;
            startBtn.textContent = '🚀 Mulai Game';
        } else {
            startBtn.disabled = true;
            startBtn.textContent = `🔫 Pilih ${2 - selectedWeapons.length} senjata lagi`;
        }
    }

    // NUI Message Handler
    window.addEventListener('message', function(event) {
        const data = event.data;

        switch(data.type) {
            case 'showUI':
                setupUI.style.display = 'flex';
                if (data.weapons) {
                    availableWeapons = data.weapons;
                    selectedWeapons = [];
                    renderWeapons();
                    updateSelectedCount();
                    updateStartButton();
                }
                break;
            case 'hideUI':
                setupUI.style.display = 'none';
                break;
            case 'showGameUI':
                gameUI.style.display = 'block';
                enemyCounter.textContent = data.enemiesLeft;
                break;
            case 'hideGameUI':
                gameUI.style.display = 'none';
                break;
            case 'updateEnemies':
                enemyCounter.textContent = data.enemiesLeft;
                break;
        }
    });

    // Button Events
    startBtn.addEventListener('click', function() {
        if (selectedWeapons.length !== 2) {
            return;
        }

        const enemyCount = document.getElementById('enemyCount').value;
        const spawnDistance = document.getElementById('spawnDistance').value;

        fetch(`https://${GetParentResourceName()}/startGame`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                enemyCount: enemyCount,
                spawnDistance: spawnDistance,
                selectedWeapons: selectedWeapons
            })
        });
    });

    closeBtn.addEventListener('click', function() {
        fetch(`https://${GetParentResourceName()}/closeUI`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({})
        });
    });

    stopGameBtn.addEventListener('click', function() {
        fetch(`https://${GetParentResourceName()}/stopGame`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({})
        });
    });

    // ESC Key Handler
    document.addEventListener('keydown', function(event) {
        if (event.key === 'Escape') {
            if (setupUI.style.display === 'flex') {
                fetch(`https://${GetParentResourceName()}/closeUI`, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify({})
                });
            }
        }
    });

    // Initialize
    updateStartButton();
});