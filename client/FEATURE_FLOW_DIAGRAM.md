# 🗺️ Chat Features Flow Diagram

## Navigation Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                         MESSAGES PAGE                            │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  🔍 Search Bar (tap) ──────────────────────┐             │  │
│  │  📋 Primary / General Tabs                 │             │  │
│  │  💬 Conversation List                      │             │  │
│  │  ✏️  New Message Button                    │             │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
         │                    │                    │
         │ tap conversation   │ tap search         │ tap new message
         ▼                    ▼                    ▼
┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
│   CHAT PAGE      │  │  SEARCH PAGE     │  │ NEW MESSAGE PAGE │
│                  │  │                  │  │                  │
│ • Messages       │  │ • Search Input   │  │ • User Search    │
│ • Input Bar      │  │ • Results List   │  │ • Recent Chats   │
│ • Media          │  │ • Tap → Chat     │  │ • Create Group   │
│ • Actions        │  │                  │  │                  │
└──────────────────┘  └──────────────────┘  └──────────────────┘
         │                                            │
         │                                            │ create group
         │                                            ▼
         │                                   ┌──────────────────┐
         │                                   │ GROUP CREATE     │
         │                                   │                  │
         │                                   │ 1. Select Users  │
         │                                   │ 2. Name Group    │
         │                                   │ 3. Set Avatar    │
         │                                   └──────────────────┘
         │
         │ (from chat page)
         ├─────────────────────────────────────────────────────┐
         │                                                       │
         ▼                                                       ▼
┌──────────────────┐                                  ┌──────────────────┐
│ MESSAGE ACTIONS  │                                  │  MEDIA VIEWERS   │
│                  │                                  │                  │
│ Long Press Menu: │                                  │ Tap Image →      │
│ • Reply          │                                  │  IMAGE VIEWER    │
│ • Forward ───────┼──────────┐                      │  • Zoom/Pan      │
│ • Copy           │          │                      │  • Actions       │
│ • Edit ──────────┼────┐     │                      │                  │
│ • Save           │    │     │                      │ Tap Video →      │
│ • Unsend         │    │     │                      │  VIDEO PLAYER    │
│ • Report         │    │     │                      │  • Play/Pause    │
└──────────────────┘    │     │                      │  • Seek          │
         │              │     │                      │  • Controls      │
         │ info icon    │     │                      │                  │
         ▼              │     │                      │ Tap Audio →      │
┌──────────────────┐    │     │                      │  AUDIO PLAYER    │
│  CHAT OPTIONS    │    │     │                      │  • Play/Pause    │
│                  │    │     │                      │  • Waveform      │
│ • Disappearing ──┼─┐  │     │                      │  • Progress      │
│ • View Profile   │ │  │     │                      └──────────────────┘
│ • Mute           │ │  │     │
│ • Search in Chat │ │  │     │
└──────────────────┘ │  │     │
                     │  │     │
                     ▼  ▼     ▼
         ┌──────────────────────────────────────┐
         │      MODAL DIALOGS                   │
         │                                      │
         │  ┌────────────────────────────────┐ │
         │  │ DISAPPEARING MESSAGE DIALOG    │ │
         │  │ • Off                          │ │
         │  │ • 24 hours                     │ │
         │  │ • 7 days                       │ │
         │  │ • 90 days                      │ │
         │  └────────────────────────────────┘ │
         │                                      │
         │  ┌────────────────────────────────┐ │
         │  │ MESSAGE EDIT DIALOG            │ │
         │  │ • Text Editor                  │ │
         │  │ • Save / Cancel                │ │
         │  └────────────────────────────────┘ │
         │                                      │
         │  ┌────────────────────────────────┐ │
         │  │ FORWARD MESSAGE PAGE           │ │
         │  │ • Select Conversations         │ │
         │  │ • Multi-select                 │ │
         │  │ • Search                       │ │
         │  │ • Send                         │ │
         │  └────────────────────────────────┘ │
         └──────────────────────────────────────┘
```

---

## Feature Interaction Map

```
┌─────────────────────────────────────────────────────────────────┐
│                      CHAT PAGE (Main Hub)                        │
└─────────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
        ▼                     ▼                     ▼
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│   MESSAGES   │    │    MEDIA     │    │   ACTIONS    │
└──────────────┘    └──────────────┘    └──────────────┘
        │                   │                    │
        ├─ Text            ├─ Images            ├─ Reply
        ├─ Images          ├─ Videos            ├─ Forward
        ├─ Videos          ├─ Audio             ├─ Edit
        ├─ Audio           │                    ├─ Delete
        ├─ Reactions       │                    ├─ React
        └─ Replies         │                    └─ Copy
                           │
        ┌──────────────────┼──────────────────┐
        │                  │                  │
        ▼                  ▼                  ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│ IMAGE VIEWER │  │ VIDEO PLAYER │  │ AUDIO PLAYER │
│              │  │              │  │              │
│ • Zoom       │  │ • Play       │  │ • Play       │
│ • Pan        │  │ • Pause      │  │ • Pause      │
│ • Save       │  │ • Seek       │  │ • Waveform   │
│ • Share      │  │ • Volume     │  │ • Progress   │
│ • Forward    │  │ • Share      │  │              │
└──────────────┘  └──────────────┘  └──────────────┘
```

---

## State Management Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                         PROVIDERS                                │
└─────────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
        ▼                     ▼                     ▼
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│ InboxProvider│    │ ChatProvider │    │TypingProvider│
│              │    │              │    │              │
│ • Convos     │    │ • Messages   │    │ • Typing     │
│ • Unread     │    │ • Loading    │    │ • Users      │
│ • Loading    │    │ • Sending    │    │              │
└──────────────┘    └──────────────┘    └──────────────┘
        │                     │                     │
        └─────────────────────┼─────────────────────┘
                              │
                              ▼
                    ┌──────────────────┐
                    │ MessageRepository│
                    │                  │
                    │ • API Calls      │
                    │ • Socket Events  │
                    │ • Local Cache    │
                    └──────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
        ▼                     ▼                     ▼
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│   Chat API   │    │SocketService │    │ ChatLocalDb  │
│              │    │              │    │              │
│ • REST       │    │ • WebSocket  │    │ • Hive       │
│ • HTTP       │    │ • Real-time  │    │ • Cache      │
└──────────────┘    └──────────────┘    └──────────────┘
```

---

## Data Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                         USER ACTION                              │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                         UI WIDGET                                │
│                    (Button, Gesture, etc.)                       │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                         PROVIDER                                 │
│                    (State Management)                            │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                         REPOSITORY                               │
│                    (Business Logic)                              │
└─────────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
        ▼                     ▼                     ▼
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│   API Call   │    │ Socket Emit  │    │ Local Cache  │
│              │    │              │    │              │
│ • HTTP       │    │ • WebSocket  │    │ • Hive DB    │
│ • REST       │    │ • Real-time  │    │ • Instant    │
└──────────────┘    └──────────────┘    └──────────────┘
        │                     │                     │
        └─────────────────────┼─────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                         RESPONSE                                 │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                         UPDATE STATE                             │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                         REBUILD UI                               │
└─────────────────────────────────────────────────────────────────┘
```

---

## Message Lifecycle

```
┌─────────────────────────────────────────────────────────────────┐
│                    USER TYPES MESSAGE                            │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    TYPING INDICATOR                              │
│                    (Socket emit)                                 │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    USER SENDS MESSAGE                            │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    OPTIMISTIC UPDATE                             │
│                    (Show immediately with temp ID)               │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    SAVE TO LOCAL DB                              │
│                    (Hive cache)                                  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    SEND TO SERVER                                │
│                    (API call)                                    │
└─────────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        │ Success             │ Error               │
        ▼                     ▼                     
┌──────────────┐    ┌──────────────┐
│ REPLACE TEMP │    │ SHOW ERROR   │
│ WITH REAL ID │    │ MARK FAILED  │
└──────────────┘    └──────────────┘
        │                     │
        └─────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────────┐
│                    SOCKET BROADCAST                              │
│                    (Other users receive)                         │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    UPDATE UI                                     │
│                    (Show sent/delivered/read status)             │
└─────────────────────────────────────────────────────────────────┘
```

---

## Feature Dependencies

```
┌─────────────────────────────────────────────────────────────────┐
│                      CORE FEATURES                               │
│                                                                  │
│  • Message Repository                                           │
│  • Socket Service                                               │
│  • Local Database                                               │
│  • Chat Provider                                                │
└─────────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
        ▼                     ▼                     ▼
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│   SEARCH     │    │    MEDIA     │    │   ACTIONS    │
│              │    │              │    │              │
│ Depends on:  │    │ Depends on:  │    │ Depends on:  │
│ • Messages   │    │ • Messages   │    │ • Messages   │
│ • Convos     │    │ • URLs       │    │ • Convos     │
└──────────────┘    └──────────────┘    └──────────────┘
        │                     │                     │
        └─────────────────────┼─────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      ENHANCED FEATURES                           │
│                                                                  │
│  • Image Viewer (depends on Media)                              │
│  • Video Player (depends on Media)                              │
│  • Audio Player (depends on Media)                              │
│  • Forward (depends on Actions + Convos)                        │
│  • Edit (depends on Actions + Messages)                         │
│  • Disappearing (depends on Actions + Settings)                 │
│  • Group Chat (depends on Convos + Users)                       │
└─────────────────────────────────────────────────────────────────┘
```

---

## Integration Points

```
┌─────────────────────────────────────────────────────────────────┐
│                         ROUTER                                   │
│                                                                  │
│  /messages              → Messages Page                         │
│  /messages/search       → Search Page                           │
│  /chat/:id              → Chat Page                             │
│  /messages/image-viewer → Image Viewer                          │
│  /messages/video-player → Video Player                          │
│  /messages/forward      → Forward Page                          │
│  /messages/group/create → Group Create                          │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                         PROVIDERS                                │
│                                                                  │
│  inboxProvider          → Conversations list                    │
│  chatProvider(id)       → Messages for conversation             │
│  typingProvider(id)     → Typing indicators                     │
│  presenceProvider       → Online/offline status                 │
│  messageSearchProvider  → Search results                        │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                         REPOSITORY                               │
│                                                                  │
│  MessageRepository      → All message operations                │
│  • getMessages()                                                │
│  • sendMessage()                                                │
│  • editMessage()        ← NEW                                   │
│  • deleteMessage()                                              │
│  • forwardMessage()     ← NEW                                   │
│  • searchMessages()     ← NEW                                   │
│  • createGroup()        ← NEW                                   │
│  • setDisappearing()    ← NEW                                   │
└─────────────────────────────────────────────────────────────────┘
```

---

## Quick Reference

### From Messages Page
- Tap conversation → Chat Page
- Tap search → Search Page
- Tap new message → New Message Page

### From Chat Page
- Tap image → Image Viewer
- Tap video → Video Player
- Tap audio → Audio Player (inline)
- Long press → Message Actions Menu
- Info icon → Chat Options Menu

### From Message Actions
- Reply → Sets reply state
- Forward → Forward Page
- Edit → Edit Dialog
- Copy → Clipboard
- Delete → Confirmation

### From Chat Options
- Disappearing → Disappearing Dialog
- Search → Search Page
- Profile → Profile Page
- Mute → Mute confirmation

---

**All features are interconnected and work seamlessly together!**
