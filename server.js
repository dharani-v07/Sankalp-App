require('dotenv').config();
const express = require('express');
const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const cors = require('cors');

const app = express();
const port = process.env.PORT || 3000;

// Middleware
app.use(cors({
  origin: '*', // tighten later: ['http://localhost:3000', 'http://10.47.124.171:3000']
  methods: ['GET','POST','PUT','PATCH','DELETE','OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));
app.use(express.json());

// MongoDB connection (DB name: sankalp-app — matches your Compass)
const mongoDbUri = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/sankalp-app';
mongoose.connect(mongoDbUri)
  .then(() => console.log('MongoDB connected:', mongoDbUri))
  .catch(err => {
    console.error('MongoDB connection failed:', err);
    process.exit(1);
  });

// ===== Schemas / Models =====

// Users
const userSchema = new mongoose.Schema({
  firstName: { type: String, required: true, trim: true },
  lastName:  { type: String, required: true, trim: true },
  mobileNumber: { type: String, required: true, unique: true, index: true },
  dob: { type: String, required: true },
  email: { type: String, required: true, unique: true, lowercase: true, index: true },
  password: { type: String, required: true },
  schoolName: { type: String, required: true },
  role: { type: String, required: true, enum: ['student', 'staff', 'authority'] },
}, { timestamps: true });

// Extra index safety (Compass shows 3 indexes already; this ensures they exist)
userSchema.index({ email: 1 }, { unique: true });
userSchema.index({ mobileNumber: 1 }, { unique: true });

userSchema.pre('save', async function(next) {
  if (this.isModified('password')) {
    const salt = await bcrypt.genSalt(10);
    this.password = await bcrypt.hash(this.password, salt);
  }
  next();
});

const User = mongoose.model('User', userSchema);

// Gamification
const gamificationSchema = new mongoose.Schema({
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', index: true },
  points: { type: Number, default: 0 },
  badges: [{ name: String, earnedAt: Date }],
  totalSessionSeconds: { type: Number, default: 0 },
}, { timestamps: true });
const Gamification = mongoose.model('Gamification', gamificationSchema);

// Drills
const drillSchema = new mongoose.Schema({
  title: String,
  type: String, // earthquake, fire, flood...
  description: String,
  createdByStaffId: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  schoolName: String,
  scheduledAt: Date,
  durationMin: Number,
  participants: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
  status: { type: String, enum: ['scheduled', 'active', 'ended'], default: 'scheduled' },
}, { timestamps: true });
const Drill = mongoose.model('Drill', drillSchema);

// Materials
const materialSchema = new mongoose.Schema({
  disasterType: { type: String, index: true }, // earthquake, flood, cyclone...
  title: String,
  sections: [{ heading: String, body: String, mediaUrls: [String] }],
  publishedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
}, { timestamps: true });
const Material = mongoose.model('Material', materialSchema);

// Quiz results
const quizResultSchema = new mongoose.Schema({
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', index: true },
  disasterType: String,
  score: Number,
  total: Number,
  takenAt: { type: Date, default: Date.now },
}, { timestamps: true });
const QuizResult = mongoose.model('QuizResult', quizResultSchema);

// ===== Health =====
app.get('/health', (req, res) => res.status(200).json({ ok: true }));
app.get('/', (req, res) => res.status(200).send('SANKALP API running'));

// ===== Auth & Users =====
app.post('/check-email', async (req, res) => {
  try {
    const { email } = req.body;
    const user = await User.findOne({ email });
    res.status(200).json({ exists: !!user });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error });
  }
});

app.post('/check-phone', async (req, res) => {
  try {
    const { phone } = req.body;
    const user = await User.findOne({ mobileNumber: phone });
    res.status(200).json({ exists: !!user });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error });
  }
});

app.post('/api/users', async (req, res) => {
  try {
    const { email, mobileNumber } = req.body;
    const existingEmail = await User.findOne({ email });
    if (existingEmail) return res.status(409).json({ message: 'Email already registered' });
    const existingPhone = await User.findOne({ mobileNumber });
    if (existingPhone) return res.status(409).json({ message: 'Phone number already registered' });

    const newUser = new User(req.body);
    await newUser.save();
    res.status(201).json({ message: 'User created successfully', user: newUser });
  } catch (error) {
    // Handle duplicate key race gracefully
    if (error?.code === 11000) {
      const dupField = Object.keys(error.keyPattern || {})[0] || 'field';
      return res.status(409).json({ message: `Duplicate ${dupField}` });
    }
    res.status(400).json({ message: 'Error creating user', error });
  }
});

app.post('/login', async (req, res) => {
  try {
    const { identifier, password } = req.body;
    const user = await User.findOne({
      $or: [{ email: identifier }, { mobileNumber: identifier }]
    });
    if (!user) return res.status(401).json({ message: 'Invalid credentials' });

    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) return res.status(401).json({ message: 'Invalid credentials' });

    const userResponse = {
      _id: user._id,
      firstName: user.firstName,
      lastName: user.lastName,
      mobileNumber: user.mobileNumber,
      dob: user.dob,
      email: user.email,
      schoolName: user.schoolName,
      role: user.role,
    };
    res.status(200).json({ message: 'Login successful', user: userResponse });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error });
  }
});

app.post('/reset-password', async (req, res) => {
  try {
    const { phone, newPassword } = req.body;
    const user = await User.findOne({ mobileNumber: phone });
    if (!user) return res.status(404).json({ message: 'User not found' });
    const salt = await bcrypt.genSalt(10);
    user.password = await bcrypt.hash(newPassword, salt);
    await user.save();
    res.status(200).json({ message: 'Password reset successfully' });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error });
  }
});

// ===== Gamification =====
app.get('/gamification/:userId', async (req, res) => {
  try {
    const state = await Gamification.findOne({ userId: req.params.userId });
    res.json(state || { points: 0, badges: [], totalSessionSeconds: 0 });
  } catch (e) { res.status(500).json({ message: 'Server error' }); }
});

app.post('/gamification/award', async (req, res) => {
  try {
    const { userId, points = 0, badge } = req.body;
    let doc = await Gamification.findOne({ userId });
    if (!doc) doc = new Gamification({ userId, points: 0, badges: [] });
    doc.points += points;
    if (badge) doc.badges.push({ name: badge, earnedAt: new Date() });
    await doc.save();
    res.json(doc);
  } catch (e) { res.status(500).json({ message: 'Server error' }); }
});

app.post('/gamification/session', async (req, res) => {
  try {
    const { userId, seconds } = req.body;
    let doc = await Gamification.findOne({ userId });
    if (!doc) doc = new Gamification({ userId, points: 0, badges: [], totalSessionSeconds: 0 });
    doc.totalSessionSeconds += Number(seconds || 0);
    await doc.save();
    res.json(doc);
  } catch (e) { res.status(500).json({ message: 'Server error' }); }
});

// ===== Drills =====
app.post('/drills', async (req, res) => {
  try {
    const drill = new Drill(req.body);
    await drill.save();
    res.status(201).json(drill);
  } catch (e) { res.status(400).json({ message: 'Error creating drill' }); }
});

app.get('/drills', async (req, res) => {
  try {
    const { schoolName } = req.query;
    const query = schoolName ? { schoolName } : {};
    const drills = await Drill.find(query).sort({ scheduledAt: 1 });
    res.json(drills);
  } catch (e) { res.status(500).json({ message: 'Server error' }); }
});

app.post('/drills/:id/join', async (req, res) => {
  try {
    const { userId } = req.body;
    const drill = await Drill.findById(req.params.id);
    if (!drill) return res.status(404).json({ message: 'Drill not found' });
    if (!drill.participants.map(String).includes(String(userId))) {
      drill.participants.push(userId);
    }
    await drill.save();
    res.json(drill);
  } catch (e) { res.status(500).json({ message: 'Server error' }); }
});

app.patch('/drills/:id/status', async (req, res) => {
  try {
    const { status } = req.body;
    const drill = await Drill.findByIdAndUpdate(req.params.id, { status }, { new: true });
    res.json(drill);
  } catch (e) { res.status(500).json({ message: 'Server error' }); }
});

// ===== Materials =====
app.get('/materials', async (req, res) => {
  try {
    const { disaster } = req.query;
    const q = disaster ? { disasterType: disaster } : {};
    const materials = await Material.find(q).sort({ updatedAt: -1 });
    res.json(materials);
  } catch (e) { res.status(500).json({ message: 'Server error' }); }
});

app.post('/materials', async (req, res) => {
  try {
    const doc = new Material(req.body);
    await doc.save();
    res.status(201).json(doc);
  } catch (e) { res.status(400).json({ message: 'Error creating material' }); }
});

app.put('/materials/:id', async (req, res) => {
  try {
    const doc = await Material.findByIdAndUpdate(req.params.id, req.body, { new: true });
    if (!doc) return res.status(404).json({ message: 'Material not found' });
    res.json(doc);
  } catch (e) { res.status(400).json({ message: 'Error updating material' }); }
});

// Seed or upsert detailed precaution materials (Before/During/After)
app.post('/materials/seed-precautions', async (req, res) => {
  try {
    const docs = [
      {
        disasterType: 'earthquake',
        title: 'Earthquake Precautions',
        sections: [
          { heading: 'Before', body: 'Anchor heavy furniture. Prepare an emergency kit (water, food, torch, whistle, medicines, copies of documents). Identify safe spots: under sturdy furniture or next to interior walls. Practice Drop-Cover-Hold drills with family. Secure gas cylinders and know how to shut off utilities. Keep shoes and a flashlight near the bed.' },
          { heading: 'During', body: 'Drop to your hands and knees, Cover head and neck under a table/desk, Hold On until shaking stops. Stay indoors; move away from windows. If outdoors, move to open area away from buildings, trees and wires. If in a vehicle, stop in a clear area and stay inside with seatbelt on.' },
          { heading: 'After', body: 'Check for injuries and hazards (gas leaks, electrical sparks). Expect aftershocks. Use text/SMS for communication. Do not use elevators. Evacuate damaged buildings. Listen to official updates. Provide first aid if trained. Check neighbors, especially elderly/children.' },
        ],
      },
      {
        disasterType: 'flood',
        title: 'Flood Precautions',
        sections: [
          { heading: 'Before', body: 'Know flood zones. Store valuables in waterproof containers and higher shelves. Prepare sandbags if advised. Keep emergency kit and battery-powered radio ready. Plan evacuation routes to higher ground. Move livestock/pets to safe areas.' },
          { heading: 'During', body: 'Avoid walking or driving through floodwaters; as little as 15–30 cm of moving water can sweep vehicles away. Stay off bridges over fast-moving water. Turn off electricity if instructed. Evacuate immediately when told. Avoid contact with water—it may be contaminated.' },
          { heading: 'After', body: 'Return home only when authorities say it is safe. Avoid standing water and debris; watch for snakes and sharp objects. Do not switch on electricity until systems are inspected. Disinfect water and food supplies. Document damage for insurance/relief.' },
        ],
      },
      {
        disasterType: 'fire',
        title: 'Fire Safety Precautions',
        sections: [
          { heading: 'Before', body: 'Install smoke alarms and test monthly. Keep extinguishers in kitchen and near exits. Create and practice a home evacuation plan with two ways out of each room. Store flammable items safely. Maintain electrical wiring and LPG connections.' },
          { heading: 'During', body: 'Stay low under smoke; cover nose/mouth with cloth. Check doors for heat before opening. Use stairs, never elevators. If clothes catch fire: Stop, Drop, and Roll. Alert others and call emergency services. If safe, use extinguisher (PASS: Pull, Aim, Squeeze, Sweep).' },
          { heading: 'After', body: 'Do not enter a burned structure until declared safe. Ventilate area; beware of rekindling. Treat minor burns with cool water (not ice). Replace damaged alarms and wiring. Seek support if experiencing stress or smoke inhalation symptoms.' },
        ],
      },
      {
        disasterType: 'cyclone',
        title: 'Cyclone & Storm Precautions',
        sections: [
          { heading: 'Before', body: 'Secure loose outdoor items. Trim weak tree branches. Charge phones and power banks. Stock non-perishable food, water, medicines. Identify nearest cyclone shelters and evacuation routes. Waterproof documents.' },
          { heading: 'During', body: 'Stay indoors away from windows; use storm shutters if available. Unplug electrical appliances. Do not step into floodwaters. Follow official advisories; avoid rumors. If ordered to evacuate, do so immediately to designated shelters.' },
          { heading: 'After', body: 'Beware of downed power lines and debris. Boil water before drinking if contamination suspected. Photograph damage for claims. Assist neighbors; report hazards to authorities. Continue monitoring weather updates.' },
        ],
      },
      {
        disasterType: 'heatwave',
        title: 'Heatwave Precautions',
        sections: [
          { heading: 'Before', body: 'Plan outdoor work for early morning or evening. Stock oral rehydration salts. Prepare cooling options (fans, shade). Identify vulnerable family members and check on them regularly.' },
          { heading: 'During', body: 'Hydrate frequently; avoid alcohol/caffeine. Wear light, loose clothing and hats. Seek shade or AC. Never leave children or pets in parked vehicles. Recognize heat exhaustion (heavy sweating, weakness) and treat promptly.' },
          { heading: 'After', body: 'Continue hydration; rest. Review work/rest cycles. Replenish supplies. Seek medical care if symptoms persist (dizziness, confusion, fainting).' },
        ],
      },
      {
        disasterType: 'landslide',
        title: 'Landslide Precautions',
        sections: [
          { heading: 'Before', body: 'Identify slope risks, drainage issues, and cracks. Avoid construction on steep unstable slopes. Plant deep-rooted vegetation. Prepare evacuation routes to stable ground.' },
          { heading: 'During', body: 'Move quickly to higher ground; do not cross active slides. Be alert to unusual sounds (cracking, rumbling). Watch for tilting trees/poles and new water seepage.' },
          { heading: 'After', body: 'Stay away from slide areas; secondary slides can occur. Check utilities and report damage. Re-enter only when declared safe. Stabilize slopes with engineering support where needed.' },
        ],
      },
      {
        disasterType: 'tsunami',
        title: 'Tsunami Precautions',
        sections: [
          { heading: 'Before', body: 'Know coastal evacuation routes and high ground. Participate in drills. Prepare go-bags. Understand natural warnings (strong/long earthquakes, sudden sea withdrawal).' },
          { heading: 'During', body: 'After a strong quake near the coast, evacuate to high ground immediately without waiting for official alerts. Move inland and stay there until all-clear.' },
          { heading: 'After', body: 'Return only when authorities declare it safe. Stay away from beaches for at least 24 hours due to multiple waves. Provide first aid and check for hazards.' },
        ],
      },
      {
        disasterType: 'pandemic',
        title: 'Pandemic Precautions',
        sections: [
          { heading: 'Before', body: 'Maintain hygiene supplies (soap, sanitizer, masks). Keep chronic medications stocked. Plan remote work/school options and care for dependents.' },
          { heading: 'During', body: 'Follow health advisories: vaccination, masking in crowded spaces, hand hygiene, physical distancing when advised. Ventilate indoor spaces. Isolate if symptomatic and get tested.' },
          { heading: 'After', body: 'Continue surveillance for new waves. Update vaccination per guidance. Address mental health and catch up on routine care.' },
        ],
      },
    ];

    const ops = docs.map(d => ({ updateOne: { filter: { disasterType: d.disasterType }, update: d, upsert: true } }));
    await Material.bulkWrite(ops);
    const all = await Material.find({}).sort({ disasterType: 1 });
    res.json({ message: 'Seeded/updated materials', count: all.length, materials: all });
  } catch (e) {
    res.status(500).json({ message: 'Server error seeding materials' });
  }
});

// Seed sample materials (disable by default)
/*
app.post('/materials/seed', async (req, res) => {
  const samples = [
    { disasterType: 'earthquake', title: 'Earthquake Basics', sections: [
      { heading: 'Preparation', body: 'Create an emergency kit...' },
      { heading: 'During', body: 'Drop, cover, and hold on...' },
      { heading: 'After', body: 'Check for injuries...' },
    ]},
    { disasterType: 'flood', title: 'Flood Safety', sections: [
      { heading: 'Preparation', body: 'Know evacuation routes...' },
      { heading: 'During', body: 'Move to higher ground...' },
      { heading: 'After', body: 'Avoid floodwaters...' },
    ]},
  ];
  await Material.insertMany(samples);
  res.json({ ok: true });
});
*/

// ===== Quiz =====
app.post('/quiz/submit', async (req, res) => {
  try {
    const { userId, disasterType, score, total } = req.body;
    const result = new QuizResult({ userId, disasterType, score, total });
    await result.save();
    res.status(201).json(result);
  } catch (e) { res.status(400).json({ message: 'Error recording quiz' }); }
});

// Simple in-memory question bank (can be moved to DB later)
const QUESTION_BANK = {
  earthquake: [
    { q: 'During an earthquake, the safest action is:', options: ['Run outside immediately', 'Drop, Cover, and Hold On', 'Stand near windows', 'Use the elevator'], answer: 1 },
    { q: 'What should you turn off after an earthquake if you smell gas?', options: ['Electricity', 'Water', 'Gas supply', 'Internet'], answer: 2 },
    { q: 'After a quake, check for:', options: ['Social media first', 'Injuries and hazards', 'New movies', 'Nothing'], answer: 1 },
  ],
  flood: [
    { q: 'Flood safety: What should you avoid driving through?', options: ['Shallow puddles', 'Floodwaters', 'Dry roads', 'Bridges'], answer: 1 },
    { q: 'After a flood, avoid:', options: ['Floodwaters', 'Bottled water', 'Checking gas leaks', 'Listening to authorities'], answer: 0 },
  ],
  fire: [
    { q: 'In a fire, you should:', options: ['Use elevator', 'Crawl low under smoke', 'Open all windows', 'Hide'], answer: 1 },
    { q: 'What to use for small kitchen grease fire?', options: ['Water', 'Lid to smother', 'Open door', 'Fan it'], answer: 1 },
  ],
  cyclone: [
    { q: 'Cyclone preparation includes:', options: ['Ignoring alerts', 'Securing loose items outdoors', 'Leaving pets unattended', 'None'], answer: 1 },
    { q: 'Storm surge means:', options: ['Strong wind only', 'Abnormal rise of sea level', 'Small waves', 'No risk'], answer: 1 },
  ],
  general: [
    { q: 'Which item belongs in an emergency kit?', options: ['Candles only', 'Whistle and flashlight', 'Perishable food', 'None'], answer: 1 },
    { q: 'Who to call for emergencies in India?', options: ['100/112', '900', '411', '808'], answer: 0 },
  ],
};

app.get('/quiz/questions', async (req, res) => {
  const type = (req.query.type || 'general').toLowerCase();
  const base = QUESTION_BANK[type] || QUESTION_BANK.general;
  // Combine if too short
  let pool = base;
  if (!pool || pool.length < 5) {
    pool = [
      ...QUESTION_BANK.earthquake,
      ...QUESTION_BANK.flood,
      ...QUESTION_BANK.fire,
      ...QUESTION_BANK.cyclone,
      ...QUESTION_BANK.general,
    ];
  }
  // Shuffle and cap 20
  const shuffled = [...pool].sort(() => Math.random() - 0.5).slice(0, 20);
  res.json(shuffled);
});

app.get('/quiz/highscore', async (req, res) => {
  try {
    const { userId, type } = req.query;
    if (!userId) return res.status(400).json({ message: 'userId required' });
    const filter = type ? { userId, disasterType: type } : { userId };
    const results = await QuizResult.find(filter).lean();
    if (!results.length) return res.json({ best: null, percent: null });
    let best = results[0], bestPct = (best.score / Math.max(best.total || 1, 1)) * 100;
    for (const r of results) {
      const pct = (r.score / Math.max(r.total || 1, 1)) * 100;
      if (pct > bestPct) { best = r; bestPct = pct; }
    }
    res.json({ best, percent: Math.round(bestPct) });
  } catch (e) { res.status(500).json({ message: 'Server error' }); }
});

// ... your auth, materials, drills, quiz routes ...

// ===== Authority Dashboard =====
app.get('/authority/dashboard', async (req, res) => {
  try {
    const school = req.query.schoolName || '';
    const drillsCount = await Drill.countDocuments({ schoolName: school });

    const users = await User.aggregate([
      { $match: { schoolName: school } },
      { $group: { _id: { role: '$role' }, count: { $sum: 1 } } },
    ]);

    const quizzes = await QuizResult.aggregate([
      { $group: { _id: '$disasterType', avgScore: { $avg: '$score' }, attempts: { $sum: 1 } } },
    ]);

    res.json({ drills: drillsCount, users, quizzes });
  } catch (e) {
    res.status(500).json({ message: 'Server error' });
  }
});

// ===== Authority Activities =====
app.get('/authority/activities', async (req, res) => {
  try {
    const school = req.query.schoolName || '';
    const drills = await Drill.find({ schoolName: school })
      .sort({ updatedAt: -1 })
      .limit(20)
      .lean();
    const items = drills.map(d => ({
      action: `Drill ${d.title || '(Untitled)'} ${d.status || ''}`.trim(),
      role: 'system',
      createdAt: d.updatedAt || d.createdAt,
    }));
    res.json(items);
  } catch (e) {
    res.status(500).json({ message: 'Server error' });
  }
});

// ===== Users: Update Profile =====
app.put('/users/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const update = { ...req.body };
    // Never allow raw password change via this endpoint
    delete update.password;

    // Uniqueness checks if changing email or mobileNumber
    if (update.email) {
      const dupeEmail = await User.findOne({ email: update.email, _id: { $ne: id } });
      if (dupeEmail) return res.status(409).json({ message: 'Email already in use' });
    }
    if (update.mobileNumber) {
      const dupePhone = await User.findOne({ mobileNumber: update.mobileNumber, _id: { $ne: id } });
      if (dupePhone) return res.status(409).json({ message: 'Phone already in use' });
    }

    const user = await User.findByIdAndUpdate(id, update, { new: true });
    if (!user) return res.status(404).json({ message: 'User not found' });

    const userResponse = {
      _id: user._id,
      firstName: user.firstName,
      lastName: user.lastName,
      mobileNumber: user.mobileNumber,
      dob: user.dob,
      email: user.email,
      schoolName: user.schoolName,
      role: user.role,
    };
    res.json({ message: 'Profile updated', user: userResponse });
  } catch (e) {
    res.status(500).json({ message: 'Server error' });
  }
});

// Optional root
app.get('/', (req, res) => res.status(200).json({ message: 'SANKALP API running' }));

// ===== 404 LAST =====
app.use((req, res) => res.status(404).json({ message: 'API endpoint not found' }));

// Listen LAST
app.listen(port, '0.0.0.0', () => {
  console.log(`Server is running on http://0.0.0.0:${port}`);
});