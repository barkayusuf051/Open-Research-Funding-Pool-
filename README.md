# 🔬 Open Research Funding Pool

A decentralized autonomous research funding platform built on Stacks blockchain using Clarity smart contracts.

## 🎯 Problem & Solution

**Problem:** Traditional research funding suffers from bureaucratic delays, bias, and limited accessibility for innovative projects.

**Solution:** A DAO-managed treasury where researchers pitch proposals, the community votes democratically, and smart contracts release funds through milestone-based tranches—making research funding faster, transparent, and accessible.

## ✨ Features

- 🏛️ **DAO Governance**: Community-driven proposal voting system
- 💰 **Treasury Management**: Secure fund deposits and withdrawals
- 📊 **Milestone-Based Funding**: Payments released in incremental stages
- 🗳️ **Weighted Voting**: Configurable voter influence system
- ⏰ **Time-Locked Voting**: Proposals have defined voting periods
- 🔒 **Multi-Role Access**: Researchers, voters, and contract owner permissions

## 🚀 Getting Started

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Node.js and npm for testing

### Installation
```bash
git clone https://github.com/your-repo/Open-Research-Funding-Pool
cd Open-Research-Funding-Pool
clarinet check
```

## 🔧 Core Functions

### 💳 Treasury Management
```clarity
(deposit-funds amount)           ; Add STX to treasury
(emergency-withdraw amount)      ; Owner-only emergency withdrawal
(get-treasury-balance)          ; View current treasury balance
```

### 📝 Proposal Lifecycle
```clarity
(create-proposal title description funding-amount milestones)  ; Submit research proposal
(vote-on-proposal proposal-id support)                       ; Vote yes/no on proposal
(finalize-proposal proposal-id)                             ; Complete voting process
(cancel-proposal proposal-id)                               ; Cancel active proposal
```

### 🎯 Milestone Management
```clarity
(create-milestone proposal-id milestone-id description funding-amount)  ; Define milestone
(complete-milestone proposal-id milestone-id)                          ; Mark completed
(release-milestone-payment proposal-id milestone-id)                   ; Release payment
```

### ⚙️ Configuration
```clarity
(set-voter-weight voter weight)      ; Assign voting power (owner only)
(set-voting-period blocks)          ; Configure voting duration
(set-min-quorum votes)             ; Set minimum participation threshold
```

## 📖 Usage Examples

### 🔬 For Researchers
```clarity
;; 1. Create a research proposal
(contract-call? .research-funding create-proposal 
  "AI Safety Research" 
  "Developing robust AI alignment protocols" 
  u1000000 
  u3)

;; 2. Define project milestones
(contract-call? .research-funding create-milestone 
  u1 u1 
  "Literature review and methodology" 
  u300000)

;; 3. Mark milestone as completed
(contract-call? .research-funding complete-milestone u1 u1)
```

### 🗳️ For Community Voters
```clarity
;; Vote on active proposals
(contract-call? .research-funding vote-on-proposal u1 true)  ; Support proposal
(contract-call? .research-funding vote-on-proposal u2 false) ; Oppose proposal
```

### 🏛️ For DAO Treasury
```clarity
;; Add funds to treasury
(contract-call? .research-funding deposit-funds u5000000)

;; Finalize voting after period ends
(contract-call? .research-funding finalize-proposal u1)

;; Release milestone payments
(contract-call? .research-funding release-milestone-payment u1 u1)
```

## 🔍 Contract Architecture

### Data Structures
- **Proposals**: Store research project details, voting results, and status
- **Votes**: Track individual voter decisions and weights
- **Milestones**: Define project phases with specific funding amounts
- **Voter Weights**: Assign voting power to community members

### Status Flow
```
voting → approved/rejected/cancelled
approved → milestones created → payments released
```

## 🛡️ Security Features

- ✅ **Access Controls**: Role-based permissions for all critical functions
- ✅ **Input Validation**: Comprehensive parameter checking
- ✅ **Double-Spending Prevention**: Milestone payment tracking
- ✅ **Emergency Controls**: Owner-only emergency withdrawal capability

## 📊 Contract Statistics

- **Total Lines**: 285+ lines of Clarity code
- **Functions**: 15 public functions, 5 read-only functions
- **Data Maps**: 4 core data structures
- **Error Handling**: 11 specific error types

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 🌟 Impact

This platform democratizes research funding by:
- 🚀 **Accelerating** grant approval processes
- 🌍 **Globalizing** access to research funding
- 🔍 **Increasing** transparency in fund allocation
- 🎯 **Supporting** innovative, high-risk projects
- 📈 **Improving** accountability through milestone tracking

---

*Built with ❤️ for the future of decentralized science*
