// resources/[warzone]/warzone_crew/html/script.js

class CrewUI {
    constructor() {
        this.currentCrewData = null;
        this.currentTab = 'members';
        this.init();
    }

    init() {
        this.bindEvents();
        this.bindTabEvents();
    }

    bindEvents() {
        // Creation events
        document.getElementById('createBtn').addEventListener('click', () => {
            this.createCrew();
        });

        document.getElementById('cancelBtn').addEventListener('click', () => {
            this.closeUI();
        });

        // Management events
        document.getElementById('inviteBtn').addEventListener('click', () => {
            this.invitePlayer();
        });

        document.getElementById('leaveBtn').addEventListener('click', () => {
            this.leaveCrew();
        });

        document.getElementById('closeBtn').addEventListener('click', () => {
            this.closeUI();
        });

        // Invitation events
        document.getElementById('acceptInviteBtn').addEventListener('click', () => {
            this.acceptInvitation();
        });

        document.getElementById('declineInviteBtn').addEventListener('click', () => {
            this.declineInvitation();
        });

        // Enter key support
        document.getElementById('crewName').addEventListener('keypress', (e) => {
            if (e.key === 'Enter') {
                this.createCrew();
            }
        });

        document.getElementById('invitePlayerId').addEventListener('keypress', (e) => {
            if (e.key === 'Enter') {
                this.invitePlayer();
            }
        });
    }

    bindTabEvents() {
        document.querySelectorAll('.tab-btn').forEach(btn => {
            btn.addEventListener('click', () => {
                this.switchTab(btn.dataset.tab);
            });
        });
    }

    switchTab(tabName) {
        // Update buttons
        document.querySelectorAll('.tab-btn').forEach(btn => {
            btn.classList.remove('active');
        });
        document.querySelector(`[data-tab="${tabName}"]`).classList.add('active');

        // Update content
        document.querySelectorAll('.tab-content').forEach(content => {
            content.classList.remove('active');
        });
        document.getElementById(tabName).classList.add('active');

        this.currentTab = tabName;
    }

    createCrew() {
        const crewName = document.getElementById('crewName').value.trim();
        
        if (!crewName) {
            this.showError('Please enter a crew name');
            return;
        }

        if (crewName.length < 3 || crewName.length > 20) {
            this.showError('Crew name must be 3-20 characters');
            return;
        }

        this.postMessage('createCrew', { crewName });
    }

    invitePlayer() {
        const playerId = document.getElementById('invitePlayerId').value;
        
        if (!playerId) {
            this.showError('Please enter a player ID');
            return;
        }

        this.postMessage('invitePlayer', { playerId: parseInt(playerId) });
        document.getElementById('invitePlayerId').value = '';
    }

    leaveCrew() {
        if (confirm('Are you sure you want to leave the crew?')) {
            this.postMessage('leaveCrew', {});
        }
    }

    acceptInvitation() {
        this.postMessage('acceptInvitation', {});
        this.hideInvitation();
    }

    declineInvitation() {
        this.postMessage('declineInvitation', {});
        this.hideInvitation();
    }

    promoteMember(identifier) {
        this.postMessage('promoteMember', { identifier });
    }

    demoteMember(identifier) {
        this.postMessage('demoteMember', { identifier });
    }

    kickMember(identifier) {
        if (confirm('Are you sure you want to kick this member?')) {
            this.postMessage('kickMember', { identifier });
        }
    }

    showCrewCreation(data) {
        document.getElementById('creationCost').textContent = data.cost || 1000;
        document.getElementById('crewCreation').style.display = 'block';
        document.getElementById('crewManagement').style.display = 'none';
        document.getElementById('app').style.display = 'block';
        
        // Focus on name input
        setTimeout(() => {
            document.getElementById('crewName').focus();
        }, 100);
    }

    showCrewManagement(data) {
        this.currentCrewData = data.crewData;
        this.updateCrewDisplay();
        
        document.getElementById('crewCreation').style.display = 'none';
        document.getElementById('crewManagement').style.display = 'block';
        document.getElementById('app').style.display = 'block';
    }

    updateCrewData(data) {
        this.currentCrewData = data.crewData;
        if (this.currentCrewData) {
            this.updateCrewDisplay();
        }
    }

    updateCrewDisplay() {
        if (!this.currentCrewData) return;

        // Update header
        document.getElementById('crewTitle').textContent = `👥 ${this.currentCrewData.name}`;
        document.getElementById('radioFreq').textContent = `📻 ${this.currentCrewData.radioFrequency}`;
        document.getElementById('memberCount').textContent = `👤 ${this.currentCrewData.memberCount}/6`;

        // Update members list
        this.updateMembersList();
    }

    updateMembersList() {
        const membersList = document.getElementById('membersList');
        membersList.innerHTML = '';

        if (!this.currentCrewData || !this.currentCrewData.members) return;

        // Sort members by role
        const sortedMembers = Object.values(this.currentCrewData.members).sort((a, b) => {
            const roleOrder = { leader: 1, officer: 2, member: 3 };
            return (roleOrder[a.role] || 4) - (roleOrder[b.role] || 4);
        });

        sortedMembers.forEach(member => {
            const memberDiv = document.createElement('div');
            memberDiv.className = 'member-item';

            const statusIcon = member.online ? '🟢' : '🔴';
            let roleIcon = '';
            if (member.role === 'leader') roleIcon = '👑 ';
            else if (member.role === 'officer') roleIcon = '⭐ ';

            memberDiv.innerHTML = `
                <div class="member-info">
                    <div class="member-name">${statusIcon} ${roleIcon}${member.displayName}</div>
                    <div class="member-role">${member.role.charAt(0).toUpperCase() + member.role.slice(1)}</div>
                </div>
                <div class="member-actions" id="actions-${member.identifier}">
                    <!-- Actions will be added based on permissions -->
                </div>
            `;

            // Add action buttons based on permissions
            const actionsDiv = memberDiv.querySelector(`#actions-${member.identifier}`);
            
            // Only show actions for other members and if current player has permissions
            if (member.identifier !== this.getCurrentPlayerIdentifier()) {
                if (this.canPromote(member)) {
                    const promoteBtn = document.createElement('button');
                    promoteBtn.className = 'action-btn promote-btn';
                    promoteBtn.textContent = 'Promote';
                    promoteBtn.onclick = () => this.promoteMember(member.identifier);
                    actionsDiv.appendChild(promoteBtn);
                }

                if (this.canDemote(member)) {
                    const demoteBtn = document.createElement('button');
                    demoteBtn.className = 'action-btn demote-btn';
                    demoteBtn.textContent = 'Demote';
                    demoteBtn.onclick = () => this.demoteMember(member.identifier);
                    actionsDiv.appendChild(demoteBtn);
                }

                if (this.canKick(member)) {
                    const kickBtn = document.createElement('button');
                    kickBtn.className = 'action-btn kick-btn';
                    kickBtn.textContent = 'Kick';
                    kickBtn.onclick = () => this.kickMember(member.identifier);
                    actionsDiv.appendChild(kickBtn);
                }
            }

            membersList.appendChild(memberDiv);
        });
    }

    getCurrentPlayerIdentifier() {
        // This would need to be passed from the client
        // For now, we'll use the leader as a placeholder
        return this.currentCrewData?.leader;
    }

    canPromote(member) {
        // Simplified permission check - in real implementation, check current player's role
        return member.role === 'member';
    }

    canDemote(member) {
        return member.role === 'officer';
    }

    canKick(member) {
        return member.role !== 'leader';
    }

    showInvitation(data) {
        document.getElementById('inviteCrewName').textContent = data.invitation.crewName;
        document.getElementById('inviterName').textContent = data.invitation.inviterName;
        document.getElementById('invitationModal').classList.add('show');
    }

    hideInvitation() {
        document.getElementById('invitationModal').classList.remove('show');
    }

    closeUI() {
        document.getElementById('app').style.display = 'none';
        this.postMessage('closeUI', {});
    }

    showError(message) {
        // You could implement a proper notification system here
        alert(message);
    }

    postMessage(type, data) {
        fetch(`https://${GetParentResourceName()}/${type}`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(data)
        }).then(response => response.json()).then(result => {
            if (!result.success && result.message) {
                this.showError(result.message);
            }
        }).catch(error => {
            console.error('Error:', error);
        });
    }
}

// Initialize UI
const crewUI = new CrewUI();

// Listen for messages from game
window.addEventListener('message', (event) => {
    const data = event.data;
    
    switch (data.type) {
        case 'showCrewCreation':
            crewUI.showCrewCreation(data);
            break;
        case 'showCrewManagement':
            crewUI.showCrewManagement(data);
            break;
        case 'updateCrewData':
            crewUI.updateCrewData(data);
            break;
        case 'showInvitation':
            crewUI.showInvitation(data);
            break;
        case 'hideInvitation':
            crewUI.hideInvitation();
            break;
        case 'hideUI':
            crewUI.closeUI();
            break;
    }
});

// Close UI with Escape key
document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') {
        crewUI.closeUI();
    }
});