# Features Guide

A comprehensive guide to all features available in the Kerala Private Bus Tracker application.

## User App Features

### 1. Real-time Bus Tracking
Track buses live on an interactive map.

**Key Capabilities:**
- Live GPS location updates
- Kalman filter for smooth marker movement
- Full route polyline display
- Selected segment highlighting
- Walking route to bus stop

**How to Use:**
1. Select a bus from the home screen
2. View live location on the map
3. Blue polyline shows your route segment
4. Gray polyline shows full route

---

### 2. Route Search
Find buses between any two stops.

**Search Methods:**
- **Stop Selection** - Choose from predefined stops
- **Current Location** - Use GPS as starting point
- **Landmark Search** - Search by landmark/place name

**Results Include:**
- Bus name and registration
- Route information
- Real-time availability status
- Estimated arrival time

---

### 3. Favorite Buses
Save frequently used buses for quick access.

**Features:**
- One-tap favorite toggle
- Favorites section on home screen
- Quick access to tracking
- Persist across sessions

---

### 4. Trip History
View past journeys and travel patterns.

**Recorded Information:**
- Bus and route details
- Date and time
- Start and end stops
- Trip duration

---

### 5. Student Pass
Apply for student concession passes.

**Application Process:**
1. Navigate to Student Pass section
2. Fill in school/college details
3. Upload ID card photo
4. Submit for admin review
5. Status updates in-app

**Status Types:**
- Pending - Under review
- Approved - Concession active
- Rejected - See reason

---

### 6. In-app Messaging
Communicate with bus conductors.

**Message Types:**
- Text messages
- Query about timing
- Report issues

**Features:**
- Real-time delivery
- Content moderation
- Message history

---

### 7. SOS Emergency Alerts
Trigger emergency alerts during travel.

**Alert Types:**
| Type | Use Case |
|------|----------|
| Emergency | General emergency |
| Harassment | Safety concerns |
| Accident | Vehicle accident |
| Medical | Health emergency |
| Other | Custom emergency |

**What Happens:**
1. Alert sent with GPS location
2. Admins notified immediately
3. Status tracked until resolved
4. Optional description

---

### 8. ETA Calculation
Estimated arrival times based on live data.

**Calculation Factors:**
- Current bus location
- Distance to destination
- Average speed
- Historical data

---

## Conductor App Features

### 1. GPS Location Sharing
Share live bus location with passengers.

**How It Works:**
1. Toggle availability ON
2. GPS tracking starts automatically
3. Location updates every 5 seconds
4. Updates stop when toggled OFF

**Data Transmitted:**
- Latitude/Longitude
- Speed (m/s)
- Heading (degrees)
- Timestamp

---

### 2. Availability Toggle
Control bus visibility to passengers.

**States:**
- **Available** - Bus visible, tracking active
- **Unavailable** - Bus hidden, can specify reason

**Unavailability Reasons:**
- Off duty
- Maintenance
- Break
- Route change

---

### 3. Delay Reporting
Notify passengers about delays.

**Delay Reasons:**
- Traffic
- Breakdown
- Weather
- Accident
- Strike
- Other

**Report Details:**
- Delay duration (1-180 mins)
- Reason selection
- Optional notes
- Auto-expires after 2 hours

---

### 4. Maintenance Reports
Submit repair and fuel reports.

**Report Types:**
- **Repair** - Vehicle issues, damage
- **Fuel** - Refueling records

**Includes:**
- Description
- Photo attachments
- Timestamp
- Admin notification

---

### 5. Passenger Chat
Respond to passenger queries.

**Features:**
- View incoming messages
- Reply to passengers
- Broadcast messages
- Message moderation

---

### 6. Conductor Profile
View and manage conductor details.

**Information:**
- Assigned bus details
- Route information
- Average rating
- Review history

---

## Admin Panel Features

### 1. Dashboard
Overview of fleet operations.

**Statistics Displayed:**
- Total buses
- Active buses
- Total conductors
- Active routes
- Active SOS alerts

---

### 2. Bus Management
Full CRUD operations for buses.

**Operations:**
| Action | Description |
|--------|-------------|
| Add | Register new bus |
| Edit | Update bus details |
| Delete | Remove bus |
| Assign Conductor | Link conductor to bus |
| Assign Route | Link route to bus |
| Toggle Availability | Enable/disable bus |

**Bus Details:**
- Name and registration
- Model and operator
- Schedule (JSONB)
- Departure times

---

### 3. Conductor Management
Manage conductor accounts.

**Operations:**
- Add new conductor
- Edit conductor details
- Assign/unassign buses
- View performance metrics
- Delete conductor

---

### 4. Route Management
Create and manage routes.

**Route Configuration:**
- Name (e.g., "Kochi - Thrissur")
- Start/End locations
- Stop sequence (ordered)
- Distance calculation
- Popular route flag

**Stop Management:**
- Add stops with coordinates
- Reorder stops
- Edit stop details
- Remove stops
- Map-based picker

**Quick Actions:**
- Create return route (reverse)
- Clone route

---

### 5. Shift Management
Schedule conductor shifts.

**Shift Details:**
- Conductor selection
- Bus assignment
- Route selection
- Start/End time
- Status tracking

**Shift Statuses:**
- Scheduled
- Active
- Completed
- Cancelled
- No Show

---

### 6. SOS Monitoring
Real-time emergency monitoring.

**Capabilities:**
- View active alerts
- Alert location on map
- Acknowledge alerts
- Mark as responding
- Resolve alerts
- Mark false alarms

---

### 7. Analytics Dashboard
Performance and usage metrics.

**Metrics:**
- Daily active buses
- Trip completion rates
- Average ratings
- Delay statistics
- Popular routes

---

### 8. Admin User Management
Manage admin accounts.

**Features:**
- Create admin accounts
- Reset passwords
- Deactivate accounts
- View activity logs

---

## Cross-cutting Features

### Theme Support
- Light mode (default)
- Dark mode
- System preference follow

### Offline Capabilities
- Cached map tiles
- Local data storage
- Offline-first sync

### Notifications
- Push notifications for:
  - Bus arriving at stop
  - Delay alerts
  - SOS acknowledgment
  - Student pass status

---

*For technical implementation, see [API Reference](./api.md)*
