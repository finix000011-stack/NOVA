#!/usr/bin/env bash
# ============================================================
#  NOVA — Discord Games & Economy Bot
#  setup.sh  |  Generates the full project
#  Usage:    bash setup.sh
# ============================================================
set -euo pipefail

PROJECT_NAME="nova"

echo "🚀 Creating NOVA project in ./${PROJECT_NAME}"

if [ -d "${PROJECT_NAME}" ]; then
  echo "⚠️  Removing existing ${PROJECT_NAME}/"
  rm -rf "${PROJECT_NAME}"
fi

mkdir -p "${PROJECT_NAME}"
cd "${PROJECT_NAME}"

# ---------- Directory tree ----------
mkdir -p prisma/migrations
mkdir -p scripts
mkdir -p src/config
mkdir -p src/core
mkdir -p src/database/repositories
mkdir -p src/services
mkdir -p src/handlers
mkdir -p src/commands/owner
mkdir -p src/commands/user
mkdir -p src/commands/slash
mkdir -p src/games
mkdir -p src/security
mkdir -p src/ui
mkdir -p src/utils
mkdir -p src/types
mkdir -p src/events
mkdir -p logs

# ============================================================
#  package.json
# ============================================================
cat > package.json <<'PKGEOF'
{
  "name": "nova",
  "version": "1.0.0",
  "description": "NOVA — High-performance Discord Games & Economy bot",
  "main": "dist/index.js",
  "type": "module",
  "engines": { "node": ">=20.10.0" },
  "scripts": {
    "build": "tsc -p tsconfig.json",
    "start": "node --enable-source-maps dist/index.js",
    "dev": "tsx watch src/index.ts",
    "prisma:generate": "prisma generate",
    "prisma:migrate": "prisma migrate deploy",
    "prisma:push": "prisma db push",
    "seed": "tsx prisma/seed.ts",
    "postinstall": "prisma generate"
  },
  "dependencies": {
    "@prisma/client": "^5.22.0",
    "discord.js": "^14.16.3",
    "dotenv": "^16.4.5",
    "ioredis": "^5.4.1",
    "pino": "^9.5.0",
    "pino-pretty": "^11.3.0",
    "zod": "^3.23.8"
  },
  "devDependencies": {
    "@types/node": "^22.9.0",
    "prisma": "^5.22.0",
    "tsx": "^4.19.2",
    "typescript": "^5.6.3"
  }
}
PKGEOF

# ============================================================
#  tsconfig.json
# ============================================================
cat > tsconfig.json <<'TSEOF'
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "outDir": "dist",
    "rootDir": "src",
    "strict": true,
    "noImplicitAny": true,
    "strictNullChecks": true,
    "noUncheckedIndexedAccess": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "sourceMap": true,
    "lib": ["ES2022"],
    "types": ["node"]
  },
  "include": ["src/**/*.ts"],
  "exclude": ["node_modules", "dist", "prisma", "scripts"]
}
TSEOF

# ============================================================
#  .gitignore
# ============================================================
cat > .gitignore <<'GITEOF'
node_modules/
dist/
.env
.env.*
!.env.example
logs/
*.log
.DS_Store
coverage/
.idea/
.vscode/
backups/
*.sqlite
*.db
GITEOF

# ============================================================
#  .env.example
# ============================================================
cat > .env.example <<'ENVEOF'
# ================= NOVA ENV =================
DISCORD_TOKEN=your_bot_token_here
OWNER_ID=your_discord_user_id_here
CLIENT_ID=your_application_id_here

NODE_ENV=production
LOG_LEVEL=info

DATABASE_URL=postgresql://nova:nova_pass@localhost:5432/nova?schema=public&connection_limit=20
REDIS_URL=redis://localhost:6379

SHARDING_ENABLED=false
SHARDING_AUTO_THRESHOLD=2000

DEFAULT_TAX_RATE=0.02
DEFAULT_DAILY=500
DEFAULT_WEEKLY=5000
ENVEOF

# ============================================================
#  prisma/schema.prisma
# ============================================================
cat > prisma/schema.prisma <<'PRISMAEOF'
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

model User {
  id            String   @id
  username      String?
  globalXp      BigInt   @default(0)
  globalLevel   Int      @default(1)
  isBlacklisted Boolean  @default(false)
  blacklistNote String?
  createdAt     DateTime @default(now())
  updatedAt     DateTime @updatedAt

  guilds        UserGuild[]
  auditActors   AuditLog[] @relation("AuditActor")

  @@index([isBlacklisted])
}

model Guild {
  id            String   @id
  name          String?
  gameChannelId String?
  locale        String   @default("ar")
  premium       Boolean  @default(false)
  taxRate       Float    @default(0.02)
  dailyReward   BigInt   @default(500)
  weeklyReward  BigInt   @default(5000)
  createdAt     DateTime @default(now())
  updatedAt     DateTime @updatedAt

  users         UserGuild[]
  transactions  Transaction[]
  lotteries     Lottery[]
  sessions      GameSession[]
  auditLogs     AuditLog[]
}

model UserGuild {
  id             String    @id @default(cuid())
  userId         String
  guildId        String
  balance        BigInt    @default(0)
  bank           BigInt    @default(0)
  level          Int       @default(1)
  xp             BigInt    @default(0)
  streak         Int       @default(0)
  lastDaily      DateTime?
  lastWeekly     DateTime?
  lastWork       DateTime?
  lastRob        DateTime?
  lastCrime      DateTime?
  lastFish       DateTime?
  lastHunt       DateTime?
  totalEarned    BigInt    @default(0)
  totalLost      BigInt    @default(0)
  totalGambled   BigInt    @default(0)
  totalWon       BigInt    @default(0)
  gamesPlayed    Int       @default(0)
  gamesWon       Int       @default(0)
  createdAt      DateTime  @default(now())
  updatedAt      DateTime  @updatedAt

  user           User      @relation(fields: [userId], references: [id], onDelete: Cascade)
  guild          Guild     @relation(fields: [guildId], references: [id], onDelete: Cascade)

  inventory      InventoryItem[]
  titles         UserTitle[]
  achievements   UserAchievement[]
  sentTx         Transaction[] @relation("TxFrom")
  receivedTx     Transaction[] @relation("TxTo")

  @@unique([userId, guildId])
  @@index([guildId, balance])
  @@index([guildId, level])
  @@index([userId])
}

enum TxType {
  DAILY
  WEEKLY
  WORK
  TRANSFER_IN
  TRANSFER_OUT
  TAX
  GAMBLE_BET
  GAMBLE_WIN
  GAMBLE_LOSS
  SHOP_BUY
  SHOP_SELL
  ROB_SUCCESS
  ROB_FAIL
  CRIME_SUCCESS
  CRIME_FAIL
  FISH
  HUNT
  LOTTERY_BUY
  LOTTERY_WIN
  OWNER_GIVE
  OWNER_TAKE
  OWNER_SET
  REWARD
}

model Transaction {
  id             String   @id @default(cuid())
  guildId        String
  fromUserId     String?
  toUserId       String?
  type           TxType
  amount         BigInt
  balanceAfter   BigInt?
  idempotencyKey String?  @unique
  metadata       Json?
  createdAt      DateTime @default(now())

  guild          Guild    @relation(fields: [guildId], references: [id], onDelete: Cascade)
  fromUser       UserGuild? @relation("TxFrom", fields: [fromUserId], references: [id], onDelete: SetNull)
  toUser         UserGuild? @relation("TxTo",   fields: [toUserId],   references: [id], onDelete: SetNull)

  @@index([guildId, createdAt])
  @@index([fromUserId, createdAt])
  @@index([toUserId, createdAt])
  @@index([type])
}

enum ItemType { ROLE TITLE BOOSTER LOOTBOX CONSUMABLE COLLECTIBLE }
enum Rarity   { COMMON UNCOMMON RARE EPIC LEGENDARY MYTHIC }

model Item {
  id          String    @id @default(cuid())
  code        String    @unique
  name        String
  description String
  emoji       String    @default("📦")
  price       BigInt
  sellPrice   BigInt
  type        ItemType
  rarity      Rarity    @default(COMMON)
  effects     Json?
  sellable    Boolean   @default(true)
  stock       Int?
  createdAt   DateTime  @default(now())

  inventory   InventoryItem[]

  @@index([type])
  @@index([rarity])
}

model InventoryItem {
  id           String   @id @default(cuid())
  userGuildId  String
  itemId       String
  quantity     Int      @default(1)
  equipped     Boolean  @default(false)
  acquiredAt   DateTime @default(now())

  userGuild    UserGuild @relation(fields: [userGuildId], references: [id], onDelete: Cascade)
  item         Item      @relation(fields: [itemId], references: [id], onDelete: Cascade)

  @@unique([userGuildId, itemId])
  @@index([userGuildId])
}

model Title {
  id          String   @id @default(cuid())
  code        String   @unique
  name        String
  description String
  emoji       String   @default("🏷️")
  price       BigInt
  rarity      Rarity   @default(COMMON)
  users       UserTitle[]
}

model UserTitle {
  id          String   @id @default(cuid())
  userGuildId String
  titleId     String
  equipped    Boolean  @default(false)
  acquiredAt  DateTime @default(now())

  userGuild   UserGuild @relation(fields: [userGuildId], references: [id], onDelete: Cascade)
  title       Title     @relation(fields: [titleId], references: [id], onDelete: Cascade)

  @@unique([userGuildId, titleId])
  @@index([userGuildId, equipped])
}

model Achievement {
  id          String   @id @default(cuid())
  code        String   @unique
  name        String
  description String
  emoji       String   @default("🏆")
  xpReward    BigInt   @default(0)
  moneyReward BigInt   @default(0)
  hidden      Boolean  @default(false)
  users       UserAchievement[]
}

model UserAchievement {
  id            String   @id @default(cuid())
  userGuildId   String
  achievementId String
  unlockedAt    DateTime @default(now())

  userGuild     UserGuild   @relation(fields: [userGuildId], references: [id], onDelete: Cascade)
  achievement   Achievement @relation(fields: [achievementId], references: [id], onDelete: Cascade)

  @@unique([userGuildId, achievementId])
  @@index([userGuildId])
}

enum LotteryStatus { OPEN DRAWING CLOSED }

model Lottery {
  id          String        @id @default(cuid())
  guildId     String
  prizePool   BigInt        @default(0)
  ticketPrice BigInt        @default(100)
  status      LotteryStatus @default(OPEN)
  startedAt   DateTime      @default(now())
  endsAt      DateTime
  winnerId    String?

  guild       Guild          @relation(fields: [guildId], references: [id], onDelete: Cascade)
  tickets     LotteryTicket[]

  @@index([guildId, status])
  @@index([endsAt])
}

model LotteryTicket {
  id          String   @id @default(cuid())
  lotteryId   String
  userId      String
  number      Int
  purchasedAt DateTime @default(now())

  lottery     Lottery  @relation(fields: [lotteryId], references: [id], onDelete: Cascade)

  @@unique([lotteryId, number])
  @@index([lotteryId, userId])
}

model GameSession {
  id         String   @id @default(cuid())
  guildId    String
  userId     String
  channelId  String
  messageId  String?
  gameType   String
  state      Json
  bet        BigInt   @default(0)
  createdAt  DateTime @default(now())
  expiresAt  DateTime

  guild      Guild    @relation(fields: [guildId], references: [id], onDelete: Cascade)

  @@index([userId, gameType])
  @@index([channelId])
  @@index([expiresAt])
}

model AuditLog {
  id        String   @id @default(cuid())
  guildId   String
  actorId   String
  action    String
  targetId  String?
  details   Json?
  createdAt DateTime @default(now())

  guild     Guild  @relation(fields: [guildId], references: [id], onDelete: Cascade)
  actor     User   @relation("AuditActor", fields: [actorId], references: [id], onDelete: Cascade)

  @@index([guildId, createdAt])
  @@index([actorId])
  @@index([action])
}

model OwnerAction {
  id        String   @id @default(cuid())
  ownerId   String
  action    String
  guildId   String?
  targetId  String?
  details   Json?
  createdAt DateTime @default(now())

  @@index([ownerId, createdAt])
  @@index([action])
}

model RateLimitBucket {
  key       String   @id
  tokens    Int
  updatedAt DateTime @updatedAt
}
PRISMAEOF

# ============================================================
#  src/config/env.ts
# ============================================================
cat > src/config/env.ts <<'EOF'
import 'dotenv/config';
import { z } from 'zod';

const schema = z.object({
  DISCORD_TOKEN: z.string().min(10, 'DISCORD_TOKEN is required'),
  OWNER_ID: z.string().regex(/^\d{15,25}$/, 'OWNER_ID must be a Discord snowflake'),
  CLIENT_ID: z.string().regex(/^\d{15,25}$/).optional(),
  NODE_ENV: z.enum(['development', 'production', 'test']).default('production'),
  LOG_LEVEL: z.enum(['fatal','error','warn','info','debug','trace']).default('info'),
  DATABASE_URL: z.string().min(1, 'DATABASE_URL is required'),
  REDIS_URL: z.string().optional().default(''),
  SHARDING_ENABLED: z.string().optional().transform((v) => v === 'true').default('false'),
  SHARDING_AUTO_THRESHOLD: z.string().optional().transform((v) => Number(v ?? '2000')).default('2000'),
  DEFAULT_TAX_RATE: z.string().optional().transform((v) => Number(v ?? '0.02')).default('0.02'),
  DEFAULT_DAILY: z.string().optional().transform((v) => Number(v ?? '500')).default('500'),
  DEFAULT_WEEKLY: z.string().optional().transform((v) => Number(v ?? '5000')).default('5000'),
});

const parsed = schema.safeParse(process.env);

if (!parsed.success) {
  // eslint-disable-next-line no-console
  console.error('❌ Invalid environment variables:');
  // eslint-disable-next-line no-console
  console.error(parsed.error.flatten().fieldErrors);
  process.exit(1);
}

export const env = {
  ...parsed.data,
  SHARDING_ENABLED: parsed.data.SHARDING_ENABLED === true,
  SHARDING_AUTO_THRESHOLD: Number(parsed.data.SHARDING_AUTO_THRESHOLD),
  DEFAULT_TAX_RATE: Number(parsed.data.DEFAULT_TAX_RATE),
  DEFAULT_DAILY: Number(parsed.data.DEFAULT_DAILY),
  DEFAULT_WEEKLY: Number(parsed.data.DEFAULT_WEEKLY),
  IS_PROD: parsed.data.NODE_ENV === 'production',
} as const;
EOF

# ============================================================
#  src/config/constants.ts
# ============================================================
cat > src/config/constants.ts <<'EOF'
export const COLORS = {
  PRIMARY: 0x5865f2,
  SUCCESS: 0x57f287,
  WARNING: 0xfee75c,
  DANGER:  0xed4245,
  GOLD:    0xf1c40f,
  DARK:    0x2b2d31,
} as const;

export const EMOJI = {
  COIN:    '🪙',
  BANK:    '🏦',
  WALLET:  '👛',
  GEM:     '💎',
  TROPHY:  '🏆',
  STAR:    '⭐',
  FIRE:    '🔥',
  DICE:    '🎲',
  SLOT:    '🎰',
  CARD:    '🃏',
  FISH:    '🐟',
  HUNT:    '🏹',
  CRIME:   '🕵️',
  ROB:     '🥷',
} as const;

export const COOLDOWNS = {
  DAILY_HOURS: 24,
  WEEKLY_HOURS: 168,
  WORK_MINUTES: 60,
  ROB_MINUTES: 30,
  CRIME_MINUTES: 45,
  FISH_MINUTES: 15,
  HUNT_MINUTES: 20,
} as const;

export const LIMITS = {
  MAX_BET: 1_000_000_000n,
  MIN_BET: 10n,
  MAX_TRANSFER: 100_000_000_000n,
  RATE_LIMIT_PER_10S: 5,
} as const;

export const TAX_RATE_DEFAULT = 0.02;
EOF

# ============================================================
#  src/core/errors.ts
# ============================================================
cat > src/core/errors.ts <<'EOF'
export class NovaError extends Error {
  public readonly code: string;
  public readonly publicMessage: string;
  public readonly meta?: Record<string, unknown>;

  constructor(code: string, internal: string, publicMessage: string, meta?: Record<string, unknown>) {
    super(internal);
    this.name = 'NovaError';
    this.code = code;
    this.publicMessage = publicMessage;
    this.meta = meta;
  }
}

export class InsufficientFundsError extends NovaError {
  constructor(needed: bigint, has: bigint) {
    super(
      'INSUFFICIENT_FUNDS',
      `Needed ${needed}, has ${has}`,
      `ليس لديك رصيد كافٍ. تحتاج **${needed}** ولديك **${has}**.`,
    );
  }
}

export class CooldownError extends NovaError {
  constructor(public readonly remainingMs: number) {
    super(
      'COOLDOWN',
      `Cooldown: ${remainingMs}ms`,
      `⏳ انتظر قليلاً. متبقٍ: **${Math.ceil(remainingMs / 1000)}** ثانية.`,
    );
  }
}

export class ValidationError extends NovaError {
  constructor(msg: string) {
    super('VALIDATION', msg, `❌ ${msg}`);
  }
}

export class NotFoundError extends NovaError {
  constructor(what: string) {
    super('NOT_FOUND', `Not found: ${what}`, `❌ لم أجد: ${what}`);
  }
}
EOF

# ============================================================
#  src/utils/logger.ts
# ============================================================
cat > src/utils/logger.ts <<'EOF'
import pino from 'pino';
import { env } from '../config/env.js';

export const logger = pino({
  level: env.LOG_LEVEL,
  redact: {
    paths: [
      'DISCORD_TOKEN', 'token', '*.token',
      'DATABASE_URL', '*.DATABASE_URL',
      'REDIS_URL', '*.REDIS_URL',
      'password', '*.password',
      'authorization', 'headers.authorization',
    ],
    censor: '[REDACTED]',
  },
  transport: env.IS_PROD
    ? undefined
    : { target: 'pino-pretty', options: { colorize: true, translateTime: 'SYS:HH:MM:ss' } },
});

export type Logger = typeof logger;
EOF

# ============================================================
#  src/utils/format.ts
# ============================================================
cat > src/utils/format.ts <<'EOF'
export function formatNumber(n: bigint | number): string {
  const s = typeof n === 'bigint' ? n.toString() : Math.floor(n).toString();
  return s.replace(/\B(?=(\d{3})+(?!\d))/g, ',');
}

export function formatCoins(n: bigint | number, emoji = '🪙'): string {
  return `${emoji} **${formatNumber(n)}**`;
}

export function formatDuration(ms: number): string {
  if (ms <= 0) return 'الآن';
  const s = Math.floor(ms / 1000);
  const d = Math.floor(s / 86400);
  const h = Math.floor((s % 86400) / 3600);
  const m = Math.floor((s % 3600) / 60);
  const sec = s % 60;
  const parts: string[] = [];
  if (d) parts.push(`${d}ي`);
  if (h) parts.push(`${h}س`);
  if (m) parts.push(`${m}د`);
  if (sec && !d && !h) parts.push(`${sec}ث`);
  return parts.join(' ');
}

export function truncate(s: string, max = 100): string {
  if (s.length <= max) return s;
  return s.slice(0, max - 1) + '…';
}
EOF

# ============================================================
#  src/utils/random.ts
# ============================================================
cat > src/utils/random.ts <<'EOF'
import { randomInt as cryptoRandomInt, randomBytes } from 'node:crypto';

/** Crypto-secure integer in [min, max] inclusive */
export function randInt(min: number, max: number): number {
  if (max < min) [min, max] = [max, min];
  return cryptoRandomInt(min, max + 1);
}

/** Crypto-secure float in [0,1) */
export function randFloat(): number {
  const buf = randomBytes(4);
  return buf.readUInt32BE(0) / 0x1_0000_0000;
}

export function pick<T>(arr: readonly T[]): T {
  if (arr.length === 0) throw new Error('pick() on empty array');
  return arr[randInt(0, arr.length - 1)]!;
}

export function shuffle<T>(arr: T[]): T[] {
  const a = [...arr];
  for (let i = a.length - 1; i > 0; i--) {
    const j = randInt(0, i);
    [a[i], a[j]] = [a[j]!, a[i]!];
  }
  return a;
}

export function weightedPick<T>(items: readonly { item: T; weight: number }[]): T {
  const total = items.reduce((s, x) => s + x.weight, 0);
  let r = randFloat() * total;
  for (const it of items) {
    r -= it.weight;
    if (r <= 0) return it.item;
  }
  return items[items.length - 1]!.item;
}
EOF

# ============================================================
#  src/database/prisma.ts
# ============================================================
cat > src/database/prisma.ts <<'EOF'
import { PrismaClient } from '@prisma/client';
import { env } from '../config/env.js';
import { logger } from '../utils/logger.js';

export const prisma = new PrismaClient({
  log: env.IS_PROD
    ? [{ emit: 'event', level: 'error' }]
    : [
        { emit: 'event', level: 'query' },
        { emit: 'event', level: 'warn' },
        { emit: 'event', level: 'error' },
      ],
});

prisma.$on('error' as never, (e: unknown) => logger.error({ e }, 'prisma error'));

if (!env.IS_PROD) {
  prisma.$on('warn' as never, (e: unknown) => logger.warn({ e }, 'prisma warn'));
}

export async function disconnectPrisma(): Promise<void> {
  await prisma.$disconnect();
}
EOF

# ============================================================
#  src/database/redis.ts
# ============================================================
cat > src/database/redis.ts <<'EOF'
import Redis from 'ioredis';
import { env } from '../config/env.js';
import { logger } from '../utils/logger.js';

export let redis: Redis | null = null;
let enabled = false;

if (env.REDIS_URL && env.REDIS_URL.trim() !== '') {
  try {
    redis = new Redis(env.REDIS_URL, {
      maxRetriesPerRequest: 3,
      lazyConnect: false,
      enableOfflineQueue: true,
      retryStrategy: (times) => Math.min(times * 100, 3000),
    });
    enabled = true;
    redis.on('error', (err) => logger.error({ err: err.message }, 'redis error'));
    redis.on('connect', () => logger.info('✅ Redis connected'));
  } catch (err) {
    logger.warn({ err }, 'Redis init failed, running without cache');
    redis = null;
    enabled = false;
  }
} else {
  logger.warn('Redis disabled (REDIS_URL empty). Using in-memory fallback.');
}

export const cacheEnabled = enabled;

/* ---------- In-memory fallback ---------- */
const memStore = new Map<string, { value: string; expiresAt: number }>();

export async function cacheGet(key: string): Promise<string | null> {
  if (redis) return redis.get(key);
  const e = memStore.get(key);
  if (!e) return null;
  if (e.expiresAt && e.expiresAt < Date.now()) {
    memStore.delete(key);
    return null;
  }
  return e.value;
}

export async function cacheSet(key: string, value: string, ttlSeconds?: number): Promise<void> {
  if (redis) {
    if (ttlSeconds) await redis.set(key, value, 'EX', ttlSeconds);
    else await redis.set(key, value);
    return;
  }
  memStore.set(key, { value, expiresAt: ttlSeconds ? Date.now() + ttlSeconds * 1000 : 0 });
}

export async function cacheDel(key: string): Promise<void> {
  if (redis) await redis.del(key);
  else memStore.delete(key);
}

export async function disconnectRedis(): Promise<void> {
  if (redis) {
    await redis.quit().catch(() => undefined);
    redis = null;
  }
}

export function getRedis(): Redis | null {
  return redis;
}
EOF

# ============================================================
#  src/security/permissions.ts
# ============================================================
cat > src/security/permissions.ts <<'EOF'
import { timingSafeEqual } from 'node:crypto';
import type { GuildMember, Message } from 'discord.js';
import { PermissionFlagsBits } from 'discord.js';
import { env } from '../config/env.js';

function safeEqual(a: string, b: string): boolean {
  const bufA = Buffer.from(a);
  const bufB = Buffer.from(b);
  if (bufA.length !== bufB.length) {
    timingSafeEqual(bufA, Buffer.alloc(bufA.length));
    return false;
  }
  return timingSafeEqual(bufA, bufB);
}

export function isOwner(userId: string): boolean {
  return safeEqual(userId, env.OWNER_ID);
}

export function isOwnerMessage(msg: Message): boolean {
  if (!msg.guild) return false;
  if (msg.author.bot) return false;
  if (!isOwner(msg.author.id)) return false;
  return msg.content.startsWith('*');
}

export function hasManageGuild(member: GuildMember | null): boolean {
  if (!member) return false;
  return member.permissions.has(PermissionFlagsBits.ManageGuild);
}
EOF

# ============================================================
#  src/security/rateLimiter.ts
# ============================================================
cat > src/security/rateLimiter.ts <<'EOF'
import { getRedis, cacheEnabled } from '../database/redis.js';

const memBuckets = new Map<string, { count: number; resetAt: number }>();

export interface RateLimitResult {
  allowed: boolean;
  remaining: number;
  resetMs: number;
}

/**
 * Token bucket: max `limit` requests per `windowSec` seconds.
 * Uses Redis if available, falls back to in-memory.
 */
export async function rateLimit(
  key: string,
  limit: number,
  windowSec: number,
): Promise<RateLimitResult> {
  const now = Date.now();
  const windowMs = windowSec * 1000;

  if (cacheEnabled) {
    const redis = getRedis()!;
    const redisKey = `nova:rl:${key}`;
    const multi = redis.multi();
    multi.incr(redisKey);
    multi.pttl(redisKey);
    const res = (await multi.exec()) as [Error | null, unknown][];
    const count = Number(res[0]?.[1] ?? 1);
    let ttl = Number(res[1]?.[1] ?? -1);
    if (ttl < 0) {
      await redis.pexpire(redisKey, windowMs);
      ttl = windowMs;
    }
    return {
      allowed: count <= limit,
      remaining: Math.max(0, limit - count),
      resetMs: ttl,
    };
  }

  const b = memBuckets.get(key);
  if (!b || b.resetAt < now) {
    memBuckets.set(key, { count: 1, resetAt: now + windowMs });
    return { allowed: true, remaining: limit - 1, resetMs: windowMs };
  }
  b.count++;
  return {
    allowed: b.count <= limit,
    remaining: Math.max(0, limit - b.count),
    resetMs: b.resetAt - now,
  };
}
EOF

echo "✅ Part 1/3 done: config, prisma, core utils, security"
# ============================================================
#  src/utils/uuid.ts
# ============================================================
cat > src/utils/uuid.ts <<'EOF'
import { randomUUID } from 'node:crypto';
export const uuid = (): string => randomUUID();
EOF

# ============================================================
#  src/utils/cooldown.ts
# ============================================================
cat > src/utils/cooldown.ts <<'EOF'
import { cacheGet, cacheSet } from '../database/redis.js';

export async function getCooldownRemaining(
  key: string,
): Promise<number> {
  const v = await cacheGet(`nova:cd:${key}`);
  if (!v) return 0;
  const expiresAt = Number(v);
  const remain = expiresAt - Date.now();
  return remain > 0 ? remain : 0;
}

export async function setCooldown(key: string, ms: number): Promise<void> {
  await cacheSet(`nova:cd:${key}`, String(Date.now() + ms), Math.ceil(ms / 1000) + 1);
}
EOF

# ============================================================
#  src/types/index.ts
# ============================================================
cat > src/types/index.ts <<'EOF'
import type { Client, Message, ChatInputCommandInteraction, Guild } from 'discord.js';

export interface NovaContext {
  client: Client;
  guild: Guild;
  userId: string;
  guildId: string;
  channelId: string;
}

export interface OwnerCommand {
  name: string;
  aliases?: string[];
  description: string;
  usage?: string;
  execute(ctx: {
    client: Client;
    message: Message;
    args: string[];
  }): Promise<void>;
}

export interface UserCommand {
  name: string;
  aliases?: string[];
  description: string;
  usage?: string;
  cooldownSec?: number;
  execute(ctx: {
    client: Client;
    message: Message;
    args: string[];
  }): Promise<void>;
}

export interface SlashCommand {
  name: string;
  description: string;
  execute(interaction: ChatInputCommandInteraction): Promise<void>;
}
EOF

# ============================================================
#  src/ui/embeds.ts
# ============================================================
cat > src/ui/embeds.ts <<'EOF'
import { EmbedBuilder } from 'discord.js';
import { COLORS } from '../config/constants.js';

export function baseEmbed(): EmbedBuilder {
  return new EmbedBuilder().setColor(COLORS.PRIMARY).setTimestamp();
}

export function successEmbed(title: string, description?: string): EmbedBuilder {
  return baseEmbed().setColor(COLORS.SUCCESS).setTitle(`✅ ${title}`).setDescription(description ?? null);
}

export function errorEmbed(title: string, description?: string): EmbedBuilder {
  return baseEmbed().setColor(COLORS.DANGER).setTitle(`❌ ${title}`).setDescription(description ?? null);
}

export function infoEmbed(title: string, description?: string): EmbedBuilder {
  return baseEmbed().setColor(COLORS.PRIMARY).setTitle(`ℹ️ ${title}`).setDescription(description ?? null);
}

export function goldEmbed(title: string, description?: string): EmbedBuilder {
  return baseEmbed().setColor(COLORS.GOLD).setTitle(`🏆 ${title}`).setDescription(description ?? null);
}

export function warnEmbed(title: string, description?: string): EmbedBuilder {
  return baseEmbed().setColor(COLORS.WARNING).setTitle(`⚠️ ${title}`).setDescription(description ?? null);
}
EOF

# ============================================================
#  src/database/repositories/userRepo.ts
# ============================================================
cat > src/database/repositories/userRepo.ts <<'EOF'
import { prisma } from '../prisma.js';

export async function ensureUser(userId: string, username?: string) {
  return prisma.user.upsert({
    where: { id: userId },
    update: username ? { username } : {},
    create: { id: userId, username: username ?? null },
  });
}

export async function ensureGuild(guildId: string, name?: string) {
  return prisma.guild.upsert({
    where: { id: guildId },
    update: name ? { name } : {},
    create: { id: guildId, name: name ?? null },
  });
}

export async function ensureUserGuild(userId: string, guildId: string, username?: string, guildName?: string) {
  await ensureUser(userId, username);
  await ensureGuild(guildId, guildName);
  return prisma.userGuild.upsert({
    where: { userId_guildId: { userId, guildId } },
    update: {},
    create: { userId, guildId },
  });
}

export async function getUserGuild(userId: string, guildId: string) {
  return prisma.userGuild.findUnique({
    where: { userId_guildId: { userId, guildId } },
  });
}
EOF

# ============================================================
#  src/services/economy.service.ts
# ============================================================
cat > src/services/economy.service.ts <<'EOF'
import { prisma } from '../database/prisma.js';
import { ensureUserGuild } from '../database/repositories/userRepo.js';
import { InsufficientFundsError, ValidationError } from '../core/errors.js';
import { TxType } from '@prisma/client';
import { uuid } from '../utils/uuid.js';

export interface TxOptions {
  idempotencyKey?: string;
  metadata?: Record<string, unknown>;
}

export async function getBalance(userId: string, guildId: string) {
  const ug = await ensureUserGuild(userId, guildId);
  return { balance: ug.balance, bank: ug.bank };
}

/** إضافة أموال للمحفظة (مع تسجيل المعاملة) */
export async function credit(
  userId: string,
  guildId: string,
  amount: bigint,
  type: TxType,
  opts: TxOptions = {},
): Promise<{ newBalance: bigint }> {
  if (amount <= 0n) throw new ValidationError('المبلغ يجب أن يكون أكبر من صفر');
  const key = opts.idempotencyKey ?? uuid();

  return prisma.$transaction(async (tx) => {
    const ug = await tx.userGuild.upsert({
      where: { userId_guildId: { userId, guildId } },
      update: {},
      create: { userId, guildId },
    });
    const updated = await tx.userGuild.update({
      where: { id: ug.id },
      data: {
        balance: { increment: amount },
        totalEarned: { increment: amount },
      },
    });
    await tx.transaction.create({
      data: {
        guildId,
        toUserId: ug.id,
        type,
        amount,
        balanceAfter: updated.balance,
        idempotencyKey: key,
        metadata: opts.metadata as never,
      },
    });
    return { newBalance: updated.balance };
  });
}

/** خصم من المحفظة */
export async function debit(
  userId: string,
  guildId: string,
  amount: bigint,
  type: TxType,
  opts: TxOptions = {},
): Promise<{ newBalance: bigint }> {
  if (amount <= 0n) throw new ValidationError('المبلغ يجب أن يكون أكبر من صفر');
  const key = opts.idempotencyKey ?? uuid();

  return prisma.$transaction(async (tx) => {
    const ug = await tx.userGuild.upsert({
      where: { userId_guildId: { userId, guildId } },
      update: {},
      create: { userId, guildId },
    });
    if (ug.balance < amount) {
      throw new InsufficientFundsError(amount, ug.balance);
    }
    const updated = await tx.userGuild.update({
      where: { id: ug.id },
      data: {
        balance: { decrement: amount },
        totalLost: { increment: amount },
      },
    });
    await tx.transaction.create({
      data: {
        guildId,
        fromUserId: ug.id,
        type,
        amount,
        balanceAfter: updated.balance,
        idempotencyKey: key,
        metadata: opts.metadata as never,
      },
    });
    return { newBalance: updated.balance };
  });
}

/** تحويل بين مستخدمين مع ضريبة */
export async function transfer(
  fromUserId: string,
  toUserId: string,
  guildId: string,
  amount: bigint,
  taxRate: number,
): Promise<{ sent: bigint; received: bigint; tax: bigint }> {
  if (amount <= 0n) throw new ValidationError('المبلغ يجب أن يكون أكبر من صفر');
  if (fromUserId === toUserId) throw new ValidationError('لا يمكن التحويل لنفسك');

  const tax = BigInt(Math.floor(Number(amount) * taxRate));
  const received = amount - tax;

  return prisma.$transaction(async (tx) => {
    const fromUG = await tx.userGuild.upsert({
      where: { userId_guildId: { userId: fromUserId, guildId } },
      update: {},
      create: { userId: fromUserId, guildId },
    });
    const toUG = await tx.userGuild.upsert({
      where: { userId_guildId: { userId: toUserId, guildId } },
      update: {},
      create: { userId: toUserId, guildId },
    });

    if (fromUG.balance < amount) {
      throw new InsufficientFundsError(amount, fromUG.balance);
    }

    const updatedFrom = await tx.userGuild.update({
      where: { id: fromUG.id },
      data: { balance: { decrement: amount }, totalLost: { increment: amount } },
    });
    const updatedTo = await tx.userGuild.update({
      where: { id: toUG.id },
      data: { balance: { increment: received }, totalEarned: { increment: received } },
    });

    await tx.transaction.createMany({
      data: [
        {
          guildId, fromUserId: fromUG.id, type: 'TRANSFER_OUT', amount,
          balanceAfter: updatedFrom.balance, idempotencyKey: uuid(),
          metadata: { toUserId } as never,
        },
        {
          guildId, toUserId: toUG.id, type: 'TRANSFER_IN', amount: received,
          balanceAfter: updatedTo.balance, idempotencyKey: uuid(),
          metadata: { fromUserId } as never,
        },
        {
          guildId, type: 'TAX', amount: tax, idempotencyKey: uuid(),
          metadata: { fromUserId, toUserId } as never,
        },
      ],
    });

    return { sent: amount, received, tax };
  });
}

/** تعيين الرصيد مباشرة (للمالك فقط) */
export async function setBalance(
  userId: string,
  guildId: string,
  newBalance: bigint,
  type: TxType = 'OWNER_SET',
): Promise<void> {
  if (newBalance < 0n) throw new ValidationError('الرصيد لا يمكن أن يكون سالباً');
  await prisma.$transaction(async (tx) => {
    const ug = await tx.userGuild.upsert({
      where: { userId_guildId: { userId, guildId } },
      update: { balance: newBalance },
      create: { userId, guildId, balance: newBalance },
    });
    await tx.transaction.create({
      data: {
        guildId, toUserId: ug.id, type, amount: newBalance,
        balanceAfter: newBalance, idempotencyKey: uuid(),
        metadata: { ownerAction: true } as never,
      },
    });
  });
}

/** إيداع في البنك */
export async function deposit(userId: string, guildId: string, amount: bigint): Promise<void> {
  if (amount <= 0n) throw new ValidationError('المبلغ يجب أن يكون أكبر من صفر');
  await prisma.$transaction(async (tx) => {
    const ug = await tx.userGuild.upsert({
      where: { userId_guildId: { userId, guildId } },
      update: {}, create: { userId, guildId },
    });
    if (ug.balance < amount) throw new InsufficientFundsError(amount, ug.balance);
    await tx.userGuild.update({
      where: { id: ug.id },
      data: { balance: { decrement: amount }, bank: { increment: amount } },
    });
  });
}

/** سحب من البنك */
export async function withdraw(userId: string, guildId: string, amount: bigint): Promise<void> {
  if (amount <= 0n) throw new ValidationError('المبلغ يجب أن يكون أكبر من صفر');
  await prisma.$transaction(async (tx) => {
    const ug = await tx.userGuild.upsert({
      where: { userId_guildId: { userId, guildId } },
      update: {}, create: { userId, guildId },
    });
    if (ug.bank < amount) throw new InsufficientFundsError(amount, ug.bank);
    await tx.userGuild.update({
      where: { id: ug.id },
      data: { bank: { decrement: amount }, balance: { increment: amount } },
    });
  });
}

/** أعلى الأرصدة في السيرفر */
export async function topBalances(guildId: string, limit = 10) {
  return prisma.userGuild.findMany({
    where: { guildId },
    orderBy: { balance: 'desc' },
    take: limit,
    include: { user: { select: { username: true } } },
  });
}
EOF

# ============================================================
#  src/services/level.service.ts
# ============================================================
cat > src/services/level.service.ts <<'EOF'
import { prisma } from '../database/prisma.js';

export function xpForLevel(level: number): bigint {
  return BigInt(Math.floor(100 * Math.pow(level, 1.5)));
}

export function totalXpForLevel(level: number): bigint {
  let sum = 0n;
  for (let i = 1; i < level; i++) sum += xpForLevel(i);
  return sum;
}

export async function addXp(
  userId: string,
  guildId: string,
  amount: number,
): Promise<{ leveledUp: boolean; newLevel: number }> {
  const ug = await prisma.userGuild.upsert({
    where: { userId_guildId: { userId, guildId } },
    update: {},
    create: { userId, guildId },
  });
  const newXp = ug.xp + BigInt(amount);
  let level = ug.level;
  let leveledUp = false;
  while (newXp >= totalXpForLevel(level + 1)) {
    level++;
    leveledUp = true;
  }
  await prisma.userGuild.update({
    where: { id: ug.id },
    data: { xp: newXp, level },
  });
  return { leveledUp, newLevel: level };
}

export async function topLevels(guildId: string, limit = 10) {
  return prisma.userGuild.findMany({
    where: { guildId },
    orderBy: [{ level: 'desc' }, { xp: 'desc' }],
    take: limit,
    include: { user: { select: { username: true } } },
  });
}
EOF

# ============================================================
#  src/services/antifraud.service.ts
# ============================================================
cat > src/services/antifraud.service.ts <<'EOF'
import { prisma } from '../database/prisma.js';
import { logger } from '../utils/logger.js';

/**
 * يكشف التلاعب المحتمل: عدد كبير من التحويلات بين نفس الحسابين في وقت قصير.
 */
export async function checkTransferAbuse(
  fromUserId: string,
  toUserId: string,
  guildId: string,
): Promise<{ suspicious: boolean; count: number }> {
  const since = new Date(Date.now() - 10 * 60 * 1000);
  const fromUG = await prisma.userGuild.findUnique({
    where: { userId_guildId: { userId: fromUserId, guildId } },
  });
  if (!fromUG) return { suspicious: false, count: 0 };

  const count = await prisma.transaction.count({
    where: {
      guildId,
      fromUserId: fromUG.id,
      type: 'TRANSFER_OUT',
      createdAt: { gte: since },
      metadata: { path: ['toUserId'], equals: toUserId },
    },
  });

  const suspicious = count >= 10;
  if (suspicious) {
    logger.warn({ fromUserId, toUserId, guildId, count }, 'Potential transfer abuse detected');
  }
  return { suspicious, count };
}
EOF

# ============================================================
#  src/games/base/BaseGame.ts
# ============================================================
cat > src/games/base/BaseGame.ts <<'EOF'
import type { Message } from 'discord.js';

export interface GameResult {
  won: boolean;
  payout: bigint;
  message: string;
}

export abstract class BaseGame {
  abstract readonly name: string;
  abstract readonly aliases: readonly string[];

  abstract play(message: Message, args: string[]): Promise<GameResult>;
}
EOF

# ============================================================
#  src/games/coinflip.ts
# ============================================================
cat > src/games/coinflip.ts <<'EOF'
import type { Message } from 'discord.js';
import { BaseGame, type GameResult } from './base/BaseGame.js';
import { randInt } from '../utils/random.js';
import { formatCoins } from '../utils/format.js';
import { debit, credit } from '../services/economy.service.js';
import { ValidationError } from '../core/errors.js';
import { LIMITS } from '../config/constants.js';

export class CoinflipGame extends BaseGame {
  readonly name = 'coinflip';
  readonly aliases = ['cf', 'قلب'] as const;

  async play(message: Message, args: string[]): Promise<GameResult> {
    const side = (args[0] ?? '').toLowerCase();
    const betStr = args[1];
    if (side !== 'heads' && side !== 'tails' && side !== 'h' && side !== 't') {
      throw new ValidationError('اختر: `heads` أو `tails` ثم المبلغ. مثال: `coinflip heads 100`');
    }
    const bet = BigInt(betStr ?? '0');
    if (bet < LIMITS.MIN_BET) throw new ValidationError(`الحد الأدنى للرهان ${LIMITS.MIN_BET}`);
    if (bet > LIMITS.MAX_BET) throw new ValidationError(`الحد الأقصى للرهان ${LIMITS.MAX_BET}`);
    if (!message.guild) throw new ValidationError('هذا الأمر داخل السيرفر فقط');

    const guildId = message.guild.id;
    const userId = message.author.id;

    await debit(userId, guildId, bet, 'GAMBLE_BET', { metadata: { game: 'coinflip' } });

    const result = randInt(0, 1) === 0 ? 'heads' : 'tails';
    const playerSide = side === 'h' ? 'heads' : side === 't' ? 'tails' : side;
    const won = result === playerSide;

    if (won) {
      const payout = bet * 2n;
      await credit(userId, guildId, payout, 'GAMBLE_WIN', { metadata: { game: 'coinflip' } });
      return {
        won: true,
        payout: payout - bet,
        message: `🪙 النتيجة: **${result}** — ربحت! ${formatCoins(payout)}`,
      };
    }
    return {
      won: false,
      payout: -bet,
      message: `🪙 النتيجة: **${result}** — خسرت ${formatCoins(bet)}`,
    };
  }
}
EOF

# ============================================================
#  src/games/dice.ts
# ============================================================
cat > src/games/dice.ts <<'EOF'
import type { Message } from 'discord.js';
import { BaseGame, type GameResult } from './base/BaseGame.js';
import { randInt } from '../utils/random.js';
import { formatCoins } from '../utils/format.js';
import { debit, credit } from '../services/economy.service.js';
import { ValidationError } from '../core/errors.js';
import { LIMITS } from '../config/constants.js';

export class DiceGame extends BaseGame {
  readonly name = 'dice';
  readonly aliases = ['نرد'] as const;

  async play(message: Message, args: string[]): Promise<GameResult> {
    const target = Number(args[0] ?? 0);
    const bet = BigInt(args[1] ?? '0');
    if (!target || target < 1 || target > 6) throw new ValidationError('اختر رقماً بين 1 و 6');
    if (bet < LIMITS.MIN_BET || bet > LIMITS.MAX_BET) throw new ValidationError('الرهان خارج النطاق');
    if (!message.guild) throw new ValidationError('هذا الأمر داخل السيرفر فقط');

    const guildId = message.guild.id;
    const userId = message.author.id;
    await debit(userId, guildId, bet, 'GAMBLE_BET', { metadata: { game: 'dice' } });

    const roll = randInt(1, 6);
    if (roll === target) {
      const payout = bet * 5n;
      await credit(userId, guildId, payout, 'GAMBLE_WIN', { metadata: { game: 'dice' } });
      return { won: true, payout: payout - bet, message: `🎲 الرقم: **${roll}** — ربحت! ${formatCoins(payout)}` };
    }
    return { won: false, payout: -bet, message: `🎲 الرقم: **${roll}** — خسرت ${formatCoins(bet)}` };
  }
}
EOF

# ============================================================
#  src/games/slots.ts
# ============================================================
cat > src/games/slots.ts <<'EOF'
import type { Message } from 'discord.js';
import { BaseGame, type GameResult } from './base/BaseGame.js';
import { pick } from '../utils/random.js';
import { formatCoins } from '../utils/format.js';
import { debit, credit } from '../services/economy.service.js';
import { ValidationError } from '../core/errors.js';
import { LIMITS } from '../config/constants.js';

const SYMBOLS = ['🍒', '🍋', '🍇', '💎', '7️⃣', '⭐'] as const;
const PAYOUTS: Record<string, bigint> = {
  '7️⃣7️⃣7️⃣': 50n,
  '💎💎💎': 25n,
  '⭐⭐⭐': 15n,
  '🍇🍇🍇': 10n,
  '🍋🍋🍋': 6n,
  '🍒🍒🍒': 4n,
};

export class SlotsGame extends BaseGame {
  readonly name = 'slots';
  readonly aliases = ['slot', 'سلوت'] as const;

  async play(message: Message, args: string[]): Promise<GameResult> {
    const bet = BigInt(args[0] ?? '0');
    if (bet < LIMITS.MIN_BET || bet > LIMITS.MAX_BET) throw new ValidationError('الرهان خارج النطاق');
    if (!message.guild) throw new ValidationError('هذا الأمر داخل السيرفر فقط');

    const guildId = message.guild.id;
    const userId = message.author.id;
    await debit(userId, guildId, bet, 'GAMBLE_BET', { metadata: { game: 'slots' } });

    const r = [pick(SYMBOLS), pick(SYMBOLS), pick(SYMBOLS)];
    const line = r.join('');
    const multiplier = PAYOUTS[line] ?? 0n;

    if (multiplier > 0n) {
      const payout = bet * multiplier;
      await credit(userId, guildId, payout, 'GAMBLE_WIN', { metadata: { game: 'slots', line } });
      return { won: true, payout: payout - bet, message: `🎰 ${line}\n💰 فوز x${multiplier}! ${formatCoins(payout)}` };
    }
    // فوز جزئي: تطابق رمزين
    if (r[0] === r[1] || r[1] === r[2] || r[0] === r[2]) {
      const partial = bet * 2n;
      await credit(userId, guildId, partial, 'GAMBLE_WIN', { metadata: { game: 'slots', line } });
      return { won: true, payout: partial - bet, message: `🎰 ${line}\n✨ رمزان متطابقان — ربحت ${formatCoins(partial)}` };
    }
    return { won: false, payout: -bet, message: `🎰 ${line}\n😔 خسرت ${formatCoins(bet)}` };
  }
}
EOF

# ============================================================
#  src/games/roulette.ts
# ============================================================
cat > src/games/roulette.ts <<'EOF'
import type { Message } from 'discord.js';
import { BaseGame, type GameResult } from './base/BaseGame.js';
import { randInt } from '../utils/random.js';
import { formatCoins } from '../utils/format.js';
import { debit, credit } from '../services/economy.service.js';
import { ValidationError } from '../core/errors.js';
import { LIMITS } from '../config/constants.js';

export class RouletteGame extends BaseGame {
  readonly name = 'roulette';
  readonly aliases = ['روليت'] as const;

  async play(message: Message, args: string[]): Promise<GameResult> {
    const choice = (args[0] ?? '').toLowerCase();
    const bet = BigInt(args[1] ?? '0');
    if (!['red', 'black', 'green', 'أحمر', 'أسود', 'أخضر'].includes(choice)) {
      throw new ValidationError('اختر: `red`, `black`, أو `green` ثم المبلغ');
    }
    if (bet < LIMITS.MIN_BET || bet > LIMITS.MAX_BET) throw new ValidationError('الرهان خارج النطاق');
    if (!message.guild) throw new ValidationError('هذا الأمر داخل السيرفر فقط');

    const guildId = message.guild.id;
    const userId = message.author.id;
    await debit(userId, guildId, bet, 'GAMBLE_BET', { metadata: { game: 'roulette' } });

    const n = randInt(0, 36);
    const color = n === 0 ? 'green' : n % 2 === 0 ? 'black' : 'red';
    const normChoice = choice === 'أحمر' ? 'red' : choice === 'أسود' ? 'black' : choice === 'أخضر' ? 'green' : choice;

    let multiplier = 0n;
    if (color === 'green' && normChoice === 'green') multiplier = 14n;
    else if (color === normChoice && color !== 'green') multiplier = 2n;

    if (multiplier > 0n) {
      const payout = bet * multiplier;
      await credit(userId, guildId, payout, 'GAMBLE_WIN', { metadata: { game: 'roulette', n } });
      return { won: true, payout: payout - bet, message: `🎡 الرقم **${n}** (${color}) — ربحت x${multiplier}! ${formatCoins(payout)}` };
    }
    return { won: false, payout: -bet, message: `🎡 الرقم **${n}** (${color}) — خسرت ${formatCoins(bet)}` };
  }
}
EOF

# ============================================================
#  src/games/blackjack.ts
# ============================================================
cat > src/games/blackjack.ts <<'EOF'
import type { Message } from 'discord.js';
import { BaseGame, type GameResult } from './base/BaseGame.js';
import { randInt } from '../utils/random.js';
import { formatCoins } from '../utils/format.js';
import { debit, credit } from '../services/economy.service.js';
import { ValidationError } from '../core/errors.js';
import { LIMITS } from '../config/constants.js';

function drawCard(): number {
  return randInt(1, 11);
}
function handTotal(cards: number[]): number {
  let sum = cards.reduce((a, b) => a + b, 0);
  let aces = cards.filter((c) => c === 11).length;
  while (sum > 21 && aces > 0) {
    sum -= 10;
    aces--;
  }
  return sum;
}

export class BlackjackGame extends BaseGame {
  readonly name = 'blackjack';
  readonly aliases = ['bj', 'بلاك جاك'] as const;

  async play(message: Message, args: string[]): Promise<GameResult> {
    const bet = BigInt(args[0] ?? '0');
    if (bet < LIMITS.MIN_BET || bet > LIMITS.MAX_BET) throw new ValidationError('الرهان خارج النطاق');
    if (!message.guild) throw new ValidationError('هذا الأمر داخل السيرفر فقط');

    const guildId = message.guild.id;
    const userId = message.author.id;
    await debit(userId, guildId, bet, 'GAMBLE_BET', { metadata: { game: 'blackjack' } });

    const player = [drawCard(), drawCard()];
    const dealer = [drawCard(), drawCard()];

    while (handTotal(player) < 17) player.push(drawCard());
    while (handTotal(dealer) < 17) dealer.push(drawCard());

    const p = handTotal(player);
    const d = handTotal(dealer);
    let result: 'win' | 'lose' | 'push' | 'blackjack' = 'lose';
    if (p > 21) result = 'lose';
    else if (d > 21) result = 'win';
    else if (p > d) result = 'win';
    else if (p < d) result = 'lose';
    else result = 'push';
    if (p === 21 && player.length === 2) result = 'blackjack';

    if (result === 'win') {
      const payout = bet * 2n;
      await credit(userId, guildId, payout, 'GAMBLE_WIN', { metadata: { game: 'blackjack' } });
      return { won: true, payout: payout - bet, message: `🃏 يدك: ${player.join('+')}=**${p}**\n🎩 يد الموزع: ${dealer.join('+')}=**${d}**\n✅ ربحت ${formatCoins(payout)}` };
    }
    if (result === 'blackjack') {
      const payout = (bet * 5n) / 2n;
      await credit(userId, guildId, payout, 'GAMBLE_WIN', { metadata: { game: 'blackjack' } });
      return { won: true, payout: payout - bet, message: `🃏 BLACKJACK! ربحت ${formatCoins(payout)}` };
    }
    if (result === 'push') {
      await credit(userId, guildId, bet, 'GAMBLE_WIN', { metadata: { game: 'blackjack', push: true } });
      return { won: false, payout: 0n, message: `🃏 تعادل (${p}=${d}). أُرجع لك رصيدك.` };
    }
    return { won: false, payout: -bet, message: `🃏 يدك: **${p}** — يد الموزع: **${d}**\n❌ خسرت ${formatCoins(bet)}` };
  }
}
EOF

# ============================================================
#  src/games/rob.ts
# ============================================================
cat > src/games/rob.ts <<'EOF'
import type { Message } from 'discord.js';
import { BaseGame, type GameResult } from './base/BaseGame.js';
import { randInt } from '../utils/random.js';
import { formatCoins } from '../utils/format.js';
import { prisma } from '../database/prisma.js';
import { ValidationError } from '../core/errors.js';
import { ensureUserGuild } from '../database/repositories/userRepo.js';

export class RobGame extends BaseGame {
  readonly name = 'rob';
  readonly aliases = ['سرقة'] as const;

  async play(message: Message, args: string[]): Promise<GameResult> {
    const target = message.mentions.users.first();
    if (!target) throw new ValidationError('منشن المستخدم الذي تريد سرقته');
    if (target.id === message.author.id) throw new ValidationError('لا تسرق نفسك!');
    if (target.bot) throw new ValidationError('لا تسرق البوتات!');
    if (!message.guild) throw new ValidationError('هذا الأمر داخل السيرفر فقط');

    const guildId = message.guild.id;
    const robberId = message.author.id;

    const robber = await ensureUserGuild(robberId, guildId, message.author.username, message.guild.name);
    const victim = await ensureUserGuild(target.id, guildId, target.username, message.guild.name);

    const lastRob = robber.lastRob?.getTime() ?? 0;
    const cooldownMs = 30 * 60 * 1000;
    if (Date.now() - lastRob < cooldownMs) {
      const remain = cooldownMs - (Date.now() - lastRob);
      throw new ValidationError(`انتظر ${Math.ceil(remain / 60000)} دقيقة قبل السرقة القادمة`);
    }

    const success = randInt(0, 99) < 40;
    const wallet = victim.balance;

    if (success && wallet > 0n) {
      const stolen = (wallet * BigInt(randInt(10, 30))) / 100n;
      await prisma.$transaction([
        prisma.userGuild.update({ where: { id: robber.id }, data: { balance: { increment: stolen }, lastRob: new Date() } }),
        prisma.userGuild.update({ where: { id: victim.id }, data: { balance: { decrement: stolen } } }),
      ]);
      return { won: true, payout: stolen, message: `🥷 نجحت السرقة! سرقت ${formatCoins(stolen)} من ${target.username}` };
    }

    const fine = robber.balance > 100n ? robber.balance / 10n : 50n;
    await prisma.userGuild.update({
      where: { id: robber.id },
      data: { balance: { decrement: fine }, lastRob: new Date() },
    });
    return { won: false, payout: -fine, message: `🚔 فشلت السرقة! غرامة ${formatCoins(fine)}` };
  }
}
EOF

# ============================================================
#  src/games/crime.ts
# ============================================================
cat > src/games/crime.ts <<'EOF'
import type { Message } from 'discord.js';
import { BaseGame, type GameResult } from './base/BaseGame.js';
import { randInt, pick } from '../utils/random.js';
import { formatCoins } from '../utils/format.js';
import { credit, debit } from '../services/economy.service.js';
import { ValidationError } from '../core/errors.js';

const CRIMES = [
  { name: 'سرقة بنك', min: 500, max: 2500 },
  { name: 'تهريب', min: 300, max: 1500 },
  { name: 'نصب', min: 200, max: 1000 },
  { name: 'قرصنة', min: 400, max: 2000 },
] as const;

export class CrimeGame extends BaseGame {
  readonly name = 'crime';
  readonly aliases = ['جريمة'] as const;

  async play(message: Message, _args: string[]): Promise<GameResult> {
    if (!message.guild) throw new ValidationError('هذا الأمر داخل السيرفر فقط');
    const guildId = message.guild.id;
    const userId = message.author.id;

    const success = randInt(0, 99) < 55;
    const crime = pick(CRIMES);

    if (success) {
      const reward = BigInt(randInt(crime.min, crime.max));
      await credit(userId, guildId, reward, 'CRIME_SUCCESS', { metadata: { crime: crime.name } });
      return { won: true, payout: reward, message: `🕵️ ${crime.name} نجحت! ربحت ${formatCoins(reward)}` };
    }
    const fine = BigInt(randInt(100, 500));
    try {
      await debit(userId, guildId, fine, 'CRIME_FAIL', { metadata: { crime: crime.name } });
    } catch {
      // تجاهل إذا الرصيد غير كافٍ
    }
    return { won: false, payout: -fine, message: `🚔 ${crime.name} فشلت! غرامة ${formatCoins(fine)}` };
  }
}
EOF

# ============================================================
#  src/games/fishing.ts
# ============================================================
cat > src/games/fishing.ts <<'EOF'
import type { Message } from 'discord.js';
import { BaseGame, type GameResult } from './base/BaseGame.js';
import { randInt } from '../utils/random.js';
import { formatCoins } from '../utils/format.js';
import { credit } from '../services/economy.service.js';
import { ValidationError } from '../core/errors.js';

const FISH = [
  { name: '🐟 سمكة صغيرة', min: 20, max: 60 },
  { name: '🐠 سمكة ملونة', min: 50, max: 120 },
  { name: '🐡 سمكة منتفخة', min: 80, max: 180 },
  { name: '🦈 قرش', min: 200, max: 500 },
  { name: '🐳 حوت', min: 500, max: 1500 },
] as const;

export class FishingGame extends BaseGame {
  readonly name = 'fish';
  readonly aliases = ['fishing', 'صيد'] as const;

  async play(message: Message, _args: string[]): Promise<GameResult> {
    if (!message.guild) throw new ValidationError('هذا الأمر داخل السيرفر فقط');
    const guildId = message.guild.id;
    const userId = message.author.id;

    if (randInt(0, 99) < 20) {
      return { won: false, payout: 0n, message: '🎣 لم تصطد شيئاً هذه المرة...' };
    }
    const f = FISH[randInt(0, FISH.length - 1)]!;
    const reward = BigInt(randInt(f.min, f.max));
    await credit(userId, guildId, reward, 'FISH', { metadata: { fish: f.name } });
    return { won: true, payout: reward, message: `🎣 اصطدت ${f.name}! ربحت ${formatCoins(reward)}` };
  }
}
EOF

# ============================================================
#  src/games/hunting.ts
# ============================================================
cat > src/games/hunting.ts <<'EOF'
import type { Message } from 'discord.js';
import { BaseGame, type GameResult } from './base/BaseGame.js';
import { randInt } from '../utils/random.js';
import { formatCoins } from '../utils/format.js';
import { credit } from '../services/economy.service.js';
import { ValidationError } from '../core/errors.js';

const PREY = [
  { name: '🐰 أرنب', min: 30, max: 80 },
  { name: '🦌 غزال', min: 100, max: 250 },
  { name: '🐗 خنزير بري', min: 150, max: 350 },
  { name: '🐻 دب', min: 400, max: 900 },
  { name: '🐉 تنين', min: 1500, max: 5000 },
] as const;

export class HuntingGame extends BaseGame {
  readonly name = 'hunt';
  readonly aliases = ['hunting', 'قنص'] as const;

  async play(message: Message, _args: string[]): Promise<GameResult> {
    if (!message.guild) throw new ValidationError('هذا الأمر داخل السيرفر فقط');
    const guildId = message.guild.id;
    const userId = message.author.id;

    if (randInt(0, 99) < 25) {
      return { won: false, payout: 0n, message: '🏹 أخطأت الهدف...' };
    }
    const p = PREY[randInt(0, PREY.length - 1)]!;
    const reward = BigInt(randInt(p.min, p.max));
    await credit(userId, guildId, reward, 'HUNT', { metadata: { prey: p.name } });
    return { won: true, payout: reward, message: `🏹 اصطدت ${p.name}! ربحت ${formatCoins(reward)}` };
  }
}
EOF

echo "✅ Part 2/3 done: services, games, UI, base infrastructure"
# ============================================================
#  src/core/client.ts
# ============================================================
cat > src/core/client.ts <<'EOF'
import { Client, GatewayIntentBits, Partials, Collection } from 'discord.js';
import type { UserCommand, OwnerCommand } from '../types/index.js';

export class NovaClient extends Client {
  public readonly userCommands = new Collection<string, UserCommand>();
  public readonly ownerCommands = new Collection<string, OwnerCommand>();
  public readonly startedAt = Date.now();

  constructor() {
    super({
      intents: [
        GatewayIntentBits.Guilds,
        GatewayIntentBits.GuildMessages,
        GatewayIntentBits.MessageContent,
        GatewayIntentBits.GuildMembers,
        GatewayIntentBits.DirectMessages,
      ],
      partials: [Partials.Channel, Partials.Message, Partials.GuildMember],
      allowedMentions: { parse: ['users'], repliedUser: false },
    });
  }
}
EOF

# ============================================================
#  src/handlers/ownerHandler.ts
# ============================================================
cat > src/handlers/ownerHandler.ts <<'EOF'
import type { Message } from 'discord.js';
import type { NovaClient } from '../core/client.js';
import { isOwnerMessage } from '../security/permissions.js';
import { logger } from '../utils/logger.js';
import { errorEmbed } from '../ui/embeds.js';

export async function handleOwnerMessage(client: NovaClient, message: Message): Promise<boolean> {
  if (!isOwnerMessage(message)) return false;

  const content = message.content.slice(1).trim();
  if (!content) return false;

  const [rawCmd, ...args] = content.split(/\s+/);
  const cmd = rawCmd?.toLowerCase();
  if (!cmd) return false;

  const command = client.ownerCommands.get(cmd)
    ?? client.ownerCommands.find((c) => c.aliases?.includes(cmd));

  if (!command) return false;

  try {
    await command.execute({ client, message, args });
  } catch (err) {
    logger.error({ err, cmd }, 'owner command failed');
    await message.reply({
      embeds: [errorEmbed('خطأ في التنفيذ', err instanceof Error ? err.message : String(err))],
    }).catch(() => undefined);
  }
  return true;
}
EOF

# ============================================================
#  src/handlers/messageHandler.ts
# ============================================================
cat > src/handlers/messageHandler.ts <<'EOF'
import type { Message } from 'discord.js';
import type { NovaClient } from '../core/client.js';
import { prisma } from '../database/prisma.js';
import { rateLimit } from '../security/rateLimiter.js';
import { LIMITS } from '../config/constants.js';
import { errorEmbed, warnEmbed } from '../ui/embeds.js';
import { logger } from '../utils/logger.js';

export async function handleUserMessage(client: NovaClient, message: Message): Promise<void> {
  if (!message.guild || message.author.bot) return;
  if (message.content.startsWith('*')) return; // يتركها للمالك

  const content = message.content.trim();
  if (!content) return;

  const [rawCmd, ...args] = content.split(/\s+/);
  const cmd = rawCmd?.toLowerCase();
  if (!cmd) return;

  const command = client.userCommands.get(cmd)
    ?? client.userCommands.find((c) => c.aliases?.includes(cmd));

  if (!command) return;

  const guild = await prisma.guild.findUnique({ where: { id: message.guild.id } });
  const gameChannel = guild?.gameChannelId;

  // إذا لم تُحدَّد قناة الألعاب، نطلب من الإدارة تحديدها
  if (!gameChannel) {
    if (Math.random() < 0.15) {
      await message.reply({
        embeds: [warnEmbed('لم يتم تحديد قناة الألعاب', 'اطلب من الإدارة استخدام `/setchannel` لتفعيل الألعاب.')],
      }).catch(() => undefined);
    }
    return;
  }

  if (message.channel.id !== gameChannel) return;

  // Rate limit
  const rl = await rateLimit(`msg:${message.author.id}`, LIMITS.RATE_LIMIT_PER_10S, 10);
  if (!rl.allowed) {
    await message.react('⏳').catch(() => undefined);
    return;
  }

  try {
    await command.execute({ client, message, args });
  } catch (err) {
    logger.error({ err, cmd }, 'user command failed');
    const msg = err instanceof Error && 'publicMessage' in err
      ? (err as { publicMessage: string }).publicMessage
      : 'حدث خطأ غير متوقع.';
    await message.reply({ embeds: [errorEmbed('خطأ', msg)] }).catch(() => undefined);
  }
}
EOF

# ============================================================
#  src/handlers/slashHandler.ts
# ============================================================
cat > src/handlers/slashHandler.ts <<'EOF'
import {
  ChatInputCommandInteraction,
  SlashCommandBuilder,
  PermissionFlagsBits,
} from 'discord.js';

export const slashCommandsData = [
  new SlashCommandBuilder()
    .setName('setchannel')
    .setDescription('تحديد روم الألعاب في هذا السيرفر')
    .setDefaultMemberPermissions(PermissionFlagsBits.ManageGuild)
    .addChannelOption((opt) =>
      opt.setName('channel').setDescription('الروم المطلوب').setRequired(true),
    )
    .toJSON(),
  new SlashCommandBuilder()
    .setName('removechannel')
    .setDescription('إزالة روم الألعاب من هذا السيرفر')
    .setDefaultMemberPermissions(PermissionFlagsBits.ManageGuild)
    .toJSON(),
];

export async function handleSlash(
  interaction: ChatInputCommandInteraction,
  handlers: {
    setchannel: (i: ChatInputCommandInteraction) => Promise<void>;
    removechannel: (i: ChatInputCommandInteraction) => Promise<void>;
  },
): Promise<void> {
  if (!interaction.isChatInputCommand()) return;
  const name = interaction.commandName;
  if (name === 'setchannel') return handlers.setchannel(interaction);
  if (name === 'removechannel') return handlers.removechannel(interaction);
}
EOF

# ============================================================
#  src/commands/slash/setchannel.ts
# ============================================================
cat > src/commands/slash/setchannel.ts <<'EOF'
import type { ChatInputCommandInteraction } from 'discord.js';
import { prisma } from '../../database/prisma.js';
import { successEmbed, errorEmbed } from '../../ui/embeds.js';

export async function setchannelCmd(interaction: ChatInputCommandInteraction): Promise<void> {
  if (!interaction.guild) {
    await interaction.reply({ content: 'داخل السيرفر فقط.', ephemeral: true });
    return;
  }
  const channel = interaction.options.getChannel('channel', true);
  if (!channel.isTextBased()) {
    await interaction.reply({ embeds: [errorEmbed('قناة غير صحيحة', 'يجب اختيار قناة نصية.')], ephemeral: true });
    return;
  }
  await prisma.guild.upsert({
    where: { id: interaction.guild.id },
    update: { gameChannelId: channel.id, name: interaction.guild.name },
    create: { id: interaction.guild.id, gameChannelId: channel.id, name: interaction.guild.name },
  });
  await interaction.reply({
    embeds: [successEmbed('تم التحديد', `قناة الألعاب: <#${channel.id}>\nاكتب الآن: \`balance\`, \`daily\`, \`slots 100\`...`)],
  });
}
EOF

# ============================================================
#  src/commands/slash/removechannel.ts
# ============================================================
cat > src/commands/slash/removechannel.ts <<'EOF'
import type { ChatInputCommandInteraction } from 'discord.js';
import { prisma } from '../../database/prisma.js';
import { successEmbed } from '../../ui/embeds.js';

export async function removechannelCmd(interaction: ChatInputCommandInteraction): Promise<void> {
  if (!interaction.guild) {
    await interaction.reply({ content: 'داخل السيرفر فقط.', ephemeral: true });
    return;
  }
  await prisma.guild.upsert({
    where: { id: interaction.guild.id },
    update: { gameChannelId: null },
    create: { id: interaction.guild.id },
  });
  await interaction.reply({
    embeds: [successEmbed('تم الإزالة', 'لم تعد قناة الألعاب محددة. استخدم `/setchannel` لإعادة التفعيل.')],
  });
}
EOF

# ============================================================
#  src/commands/owner/give.ts
# ============================================================
cat > src/commands/owner/give.ts <<'EOF'
import type { OwnerCommand } from '../../types/index.js';
import { credit } from '../../services/economy.service.js';
import { successEmbed, errorEmbed } from '../../ui/embeds.js';
import { formatCoins } from '../../utils/format.js';

export const giveCmd: OwnerCommand = {
  name: 'give',
  aliases: ['add'],
  description: 'إعطاء رصيد لمستخدم',
  usage: '*give @user <amount>',
  async execute({ message, args }) {
    const target = message.mentions.users.first();
    const amount = BigInt(args[1] ?? '0');
    if (!target || amount <= 0n) {
      await message.reply({ embeds: [errorEmbed('استخدام', '*give @user <amount>')] });
      return;
    }
    if (!message.guild) return;
    await credit(target.id, message.guild.id, amount, 'OWNER_GIVE');
    await message.reply({ embeds: [successEmbed('تم', `أُعطي ${target.username} ${formatCoins(amount)}`)] });
  },
};
EOF

# ============================================================
#  src/commands/owner/take.ts
# ============================================================
cat > src/commands/owner/take.ts <<'EOF'
import type { OwnerCommand } from '../../types/index.js';
import { debit } from '../../services/economy.service.js';
import { successEmbed, errorEmbed } from '../../ui/embeds.js';
import { formatCoins } from '../../utils/format.js';

export const takeCmd: OwnerCommand = {
  name: 'take',
  description: 'سحب رصيد من مستخدم',
  usage: '*take @user <amount>',
  async execute({ message, args }) {
    const target = message.mentions.users.first();
    const amount = BigInt(args[1] ?? '0');
    if (!target || amount <= 0n) {
      await message.reply({ embeds: [errorEmbed('استخدام', '*take @user <amount>')] });
      return;
    }
    if (!message.guild) return;
    try {
      await debit(target.id, message.guild.id, amount, 'OWNER_TAKE');
      await message.reply({ embeds: [successEmbed('تم', `سُحب من ${target.username} ${formatCoins(amount)}`)] });
    } catch {
      await message.reply({ embeds: [errorEmbed('فشل', 'الرصيد غير كافٍ.')] });
    }
  },
};
EOF

# ============================================================
#  src/commands/owner/setmoney.ts
# ============================================================
cat > src/commands/owner/setmoney.ts <<'EOF'
import type { OwnerCommand } from '../../types/index.js';
import { setBalance } from '../../services/economy.service.js';
import { successEmbed, errorEmbed } from '../../ui/embeds.js';
import { formatCoins } from '../../utils/format.js';

export const setmoneyCmd: OwnerCommand = {
  name: 'setmoney',
  description: 'تعيين رصيد مستخدم',
  usage: '*setmoney @user <amount>',
  async execute({ message, args }) {
    const target = message.mentions.users.first();
    const amount = BigInt(args[1] ?? '0');
    if (!target || amount < 0n) {
      await message.reply({ embeds: [errorEmbed('استخدام', '*setmoney @user <amount>')] });
      return;
    }
    if (!message.guild) return;
    await setBalance(target.id, message.guild.id, amount);
    await message.reply({ embeds: [successEmbed('تم', `رصيد ${target.username} = ${formatCoins(amount)}`)] });
  },
};
EOF

# ============================================================
#  src/commands/owner/reset.ts
# ============================================================
cat > src/commands/owner/reset.ts <<'EOF'
import type { OwnerCommand } from '../../types/index.js';
import { prisma } from '../../database/prisma.js';
import { successEmbed, errorEmbed } from '../../ui/embeds.js';

export const resetCmd: OwnerCommand = {
  name: 'reset',
  description: 'تصفير رصيد مستخدم أو السيرفر بالكامل',
  usage: '*reset @user | *reset all',
  async execute({ message, args }) {
    if (!message.guild) return;
    const first = args[0];
    if (!first) {
      await message.reply({ embeds: [errorEmbed('استخدام', '*reset @user أو *reset all')] });
      return;
    }
    if (first === 'all') {
      const r = await prisma.userGuild.updateMany({
        where: { guildId: message.guild.id },
        data: { balance: 0n, bank: 0n },
      });
      await message.reply({ embeds: [successEmbed('تم', `تم تصفير ${r.count} مستخدم.`)] });
      return;
    }
    const target = message.mentions.users.first();
    if (!target) {
      await message.reply({ embeds: [errorEmbed('استخدام', '*reset @user')] });
      return;
    }
    await prisma.userGuild.updateMany({
      where: { guildId: message.guild.id, userId: target.id },
      data: { balance: 0n, bank: 0n },
    });
    await message.reply({ embeds: [successEmbed('تم', `تم تصفير رصيد ${target.username}`)] });
  },
};
EOF

# ============================================================
#  src/commands/owner/ban.ts
# ============================================================
cat > src/commands/owner/ban.ts <<'EOF'
import type { OwnerCommand } from '../../types/index.js';
import { prisma } from '../../database/prisma.js';
import { successEmbed, errorEmbed } from '../../ui/embeds.js';

export const banCmd: OwnerCommand = {
  name: 'ban',
  description: 'حظر مستخدم من البوت',
  usage: '*ban @user [reason]',
  async execute({ message, args }) {
    const target = message.mentions.users.first();
    if (!target) {
      await message.reply({ embeds: [errorEmbed('استخدام', '*ban @user [reason]')] });
      return;
    }
    const reason = args.slice(1).join(' ') || null;
    await prisma.user.upsert({
      where: { id: target.id },
      update: { isBlacklisted: true, blacklistNote: reason },
      create: { id: target.id, username: target.username, isBlacklisted: true, blacklistNote: reason },
    });
    await message.reply({ embeds: [successEmbed('تم الحظر', `${target.username}${reason ? `\nالسبب: ${reason}` : ''}`)] });
  },
};
EOF

# ============================================================
#  src/commands/owner/unban.ts
# ============================================================
cat > src/commands/owner/unban.ts <<'EOF'
import type { OwnerCommand } from '../../types/index.js';
import { prisma } from '../../database/prisma.js';
import { successEmbed, errorEmbed } from '../../ui/embeds.js';

export const unbanCmd: OwnerCommand = {
  name: 'unban',
  description: 'رفع الحظر عن مستخدم',
  usage: '*unban @user',
  async execute({ message }) {
    const target = message.mentions.users.first();
    if (!target) {
      await message.reply({ embeds: [errorEmbed('استخدام', '*unban @user')] });
      return;
    }
    await prisma.user.upsert({
      where: { id: target.id },
      update: { isBlacklisted: false, blacklistNote: null },
      create: { id: target.id, username: target.username },
    });
    await message.reply({ embeds: [successEmbed('تم رفع الحظر', `${target.username}`)] });
  },
};
EOF

# ============================================================
#  src/commands/owner/broadcast.ts
# ============================================================
cat > src/commands/owner/broadcast.ts <<'EOF'
import type { OwnerCommand } from '../../types/index.js';
import { successEmbed, errorEmbed, infoEmbed } from '../../ui/embeds.js';
import { logger } from '../../utils/logger.js';

export const broadcastCmd: OwnerCommand = {
  name: 'broadcast',
  description: 'إرسال رسالة لكل السيرفرات',
  usage: '*broadcast <message>',
  async execute({ client, message, args }) {
    const text = args.join(' ');
    if (!text) {
      await message.reply({ embeds: [errorEmbed('استخدام', '*broadcast <message>')] });
      return;
    }
    let ok = 0, fail = 0;
    for (const guild of client.guilds.cache.values()) {
      const g = await client.guilds.fetch(guild.id).catch(() => null);
      if (!g) { fail++; continue; }
      const sys = g.systemChannel;
      if (!sys) { fail++; continue; }
      try {
        await sys.send({ embeds: [infoEmbed('📢 إعلان', text)] });
        ok++;
      } catch (e) {
        fail++;
        logger.debug({ e, guild: g.id }, 'broadcast failed');
      }
    }
    await message.reply({ embeds: [successEmbed('تم', `وصل: ${ok} | فشل: ${fail}`)] });
  },
};
EOF

# ============================================================
#  src/commands/owner/reload.ts
# ============================================================
cat > src/commands/owner/reload.ts <<'EOF'
import type { OwnerCommand } from '../../types/index.js';
import { successEmbed } from '../../ui/embeds.js';

export const reloadCmd: OwnerCommand = {
  name: 'reload',
  description: 'إعادة تحميل معلومات البوت (بدون إعادة تشغيل)',
  async execute({ client, message }) {
    const guilds = client.guilds.cache.size;
    const users = client.users.cache.size;
    await message.reply({ embeds: [successEmbed('تم', `السيرفرات: ${guilds}\nالمستخدمون: ${users}`)] });
  },
};
EOF

# ============================================================
#  src/commands/owner/status.ts
# ============================================================
cat > src/commands/owner/status.ts <<'EOF'
import type { OwnerCommand } from '../../types/index.js';
import { baseEmbed } from '../../ui/embeds.js';
import { COLORS } from '../../config/constants.js';

export const statusCmd: OwnerCommand = {
  name: 'status',
  description: 'حالة البوت',
  async execute({ client, message }) {
    const up = Date.now() - client.startedAt;
    const s = Math.floor(up / 1000);
    const embed = baseEmbed()
      .setColor(COLORS.PRIMARY)
      .setTitle('📊 حالة NOVA')
      .addFields(
        { name: 'السيرفرات', value: `${client.guilds.cache.size}`, inline: true },
        { name: 'المستخدمون', value: `${client.users.cache.size}`, inline: true },
        { name: 'زمن التشغيل', value: `${Math.floor(s / 3600)}س ${Math.floor((s % 3600) / 60)}د`, inline: true },
        { name: 'Ping', value: `${client.ws.ping}ms`, inline: true },
        { name: 'Node', value: process.version, inline: true },
      );
    await message.reply({ embeds: [embed] });
  },
};
EOF

# ============================================================
#  src/commands/user/balance.ts
# ============================================================
cat > src/commands/user/balance.ts <<'EOF'
import type { UserCommand } from '../../types/index.js';
import { getBalance } from '../../services/economy.service.js';
import { goldEmbed } from '../../ui/embeds.js';
import { formatCoins } from '../../utils/format.js';

export const balanceCmd: UserCommand = {
  name: 'balance',
  aliases: ['bal', 'رصيد'],
  description: 'عرض رصيدك',
  cooldownSec: 3,
  async execute({ message }) {
    if (!message.guild) return;
    const target = message.mentions.users.first() ?? message.author;
    const { balance, bank } = await getBalance(target.id, message.guild.id);
    const total = balance + bank;
    const embed = goldEmbed('💰 الرصيد')
      .setDescription(`**${target.username}**`)
      .addFields(
        { name: '👛 المحفظة', value: formatCoins(balance), inline: true },
        { name: '🏦 البنك', value: formatCoins(bank), inline: true },
        { name: '📊 الإجمالي', value: formatCoins(total), inline: true },
      );
    await message.reply({ embeds: [embed] });
  },
};
EOF

# ============================================================
#  src/commands/user/daily.ts
# ============================================================
cat > src/commands/user/daily.ts <<'EOF'
import type { UserCommand } from '../../types/index.js';
import { credit } from '../../services/economy.service.js';
import { ensureUserGuild } from '../../database/repositories/userRepo.js';
import { prisma } from '../../database/prisma.js';
import { successEmbed, warnEmbed } from '../../ui/embeds.js';
import { formatCoins, formatDuration } from '../../utils/format.js';
import { env } from '../../config/env.js';

export const dailyCmd: UserCommand = {
  name: 'daily',
  aliases: ['يومي'],
  description: 'المكافأة اليومية',
  async execute({ message }) {
    if (!message.guild) return;
    const ug = await ensureUserGuild(message.author.id, message.guild.id, message.author.username, message.guild.name);
    const now = Date.now();
    const last = ug.lastDaily?.getTime() ?? 0;
    const cd = 24 * 60 * 60 * 1000;
    if (now - last < cd) {
      await message.reply({ embeds: [warnEmbed('انتظر', `متبقٍ ${formatDuration(cd - (now - last))}`)] });
      return;
    }
    // Streak
    const streak = now - last < 48 * 60 * 60 * 1000 ? ug.streak + 1 : 1;
    const base = BigInt(env.DEFAULT_DAILY);
    const bonus = base * BigInt(Math.min(streak - 1, 6)) / 10n;
    const reward = base + bonus;
    await credit(message.author.id, message.guild.id, reward, 'DAILY');
    await prisma.userGuild.update({ where: { id: ug.id }, data: { lastDaily: new Date(), streak } });
    await message.reply({ embeds: [successEmbed('مكافأة يومية', `حصلت على ${formatCoins(reward)}\n🔥 streak: **${streak}**`)] });
  },
};
EOF

# ============================================================
#  src/commands/user/weekly.ts
# ============================================================
cat > src/commands/user/weekly.ts <<'EOF'
import type { UserCommand } from '../../types/index.js';
import { credit } from '../../services/economy.service.js';
import { ensureUserGuild } from '../../database/repositories/userRepo.js';
import { prisma } from '../../database/prisma.js';
import { successEmbed, warnEmbed } from '../../ui/embeds.js';
import { formatCoins, formatDuration } from '../../utils/format.js';
import { env } from '../../config/env.js';

export const weeklyCmd: UserCommand = {
  name: 'weekly',
  description: 'المكافأة الأسبوعية',
  async execute({ message }) {
    if (!message.guild) return;
    const ug = await ensureUserGuild(message.author.id, message.guild.id, message.author.username, message.guild.name);
    const now = Date.now();
    const last = ug.lastWeekly?.getTime() ?? 0;
    const cd = 7 * 24 * 60 * 60 * 1000;
    if (now - last < cd) {
      await message.reply({ embeds: [warnEmbed('انتظر', `متبقٍ ${formatDuration(cd - (now - last))}`)] });
      return;
    }
    const reward = BigInt(env.DEFAULT_WEEKLY);
    await credit(message.author.id, message.guild.id, reward, 'WEEKLY');
    await prisma.userGuild.update({ where: { id: ug.id }, data: { lastWeekly: new Date() } });
    await message.reply({ embeds: [successEmbed('مكافأة أسبوعية', `حصلت على ${formatCoins(reward)}`)] });
  },
};
EOF

# ============================================================
#  src/commands/user/work.ts
# ============================================================
cat > src/commands/user/work.ts <<'EOF'
import type { UserCommand } from '../../types/index.js';
import { credit } from '../../services/economy.service.js';
import { ensureUserGuild } from '../../database/repositories/userRepo.js';
import { prisma } from '../../database/prisma.js';
import { successEmbed, warnEmbed } from '../../ui/embeds.js';
import { formatCoins, formatDuration } from '../../utils/format.js';
import { randInt } from '../../utils/random.js';

const JOBS = ['مبرمج', 'طبيب', 'طيار', 'مهندس', 'مزارع', 'صياد', 'تاجر', 'حارس'];

export const workCmd: UserCommand = {
  name: 'work',
  aliases: ['عمل'],
  description: 'اعمل لكسب المال',
  async execute({ message }) {
    if (!message.guild) return;
    const ug = await ensureUserGuild(message.author.id, message.guild.id, message.author.username, message.guild.name);
    const now = Date.now();
    const last = ug.lastWork?.getTime() ?? 0;
    const cd = 60 * 60 * 1000;
    if (now - last < cd) {
      await message.reply({ embeds: [warnEmbed('أنت متعب', `متبقٍ ${formatDuration(cd - (now - last))}`)] });
      return;
    }
    const job = JOBS[randInt(0, JOBS.length - 1)]!;
    const reward = BigInt(randInt(100, 400));
    await credit(message.author.id, message.guild.id, reward, 'WORK');
    await prisma.userGuild.update({ where: { id: ug.id }, data: { lastWork: new Date() } });
    await message.reply({ embeds: [successEmbed('عملت كـ ' + job, `ربحت ${formatCoins(reward)}`)] });
  },
};
EOF

# ============================================================
#  src/commands/user/pay.ts
# ============================================================
cat > src/commands/user/pay.ts <<'EOF'
import type { UserCommand } from '../../types/index.js';
import { transfer } from '../../services/economy.service.js';
import { successEmbed, errorEmbed } from '../../ui/embeds.js';
import { formatCoins } from '../../utils/format.js';
import { prisma } from '../../database/prisma.js';
import { checkTransferAbuse } from '../../services/antifraud.service.js';
import { env } from '../../config/env.js';

export const payCmd: UserCommand = {
  name: 'pay',
  aliases: ['transfer', 'تحويل'],
  description: 'تحويل مال لمستخدم',
  async execute({ message, args }) {
    if (!message.guild) return;
    const target = message.mentions.users.first();
    const amount = BigInt(args[1] ?? '0');
    if (!target || amount <= 0n) {
      await message.reply({ embeds: [errorEmbed('استخدام', 'pay @user <amount>')] });
      return;
    }
    if (target.id === message.author.id) {
      await message.reply({ embeds: [errorEmbed('خطأ', 'لا تحوّل لنفسك.')] });
      return;
    }
    const fraud = await checkTransferAbuse(message.author.id, target.id, message.guild.id);
    if (fraud.suspicious) {
      await message.reply({ embeds: [errorEmbed('مشبوه', 'نشاط تحويلات مشبوه. تم رفض العملية.')] });
      return;
    }
    const guild = await prisma.guild.findUnique({ where: { id: message.guild.id } });
    const taxRate = guild?.taxRate ?? env.DEFAULT_TAX_RATE;
    const r = await transfer(message.author.id, target.id, message.guild.id, amount, taxRate);
    await message.reply({
      embeds: [successEmbed('تم التحويل', `أرسلت ${formatCoins(r.sent)} → استلم ${target.username} ${formatCoins(r.received)} (ضريبة ${formatCoins(r.tax)})`)],
    });
  },
};
EOF

# ============================================================
#  src/commands/user/bank.ts
# ============================================================
cat > src/commands/user/bank.ts <<'EOF'
import type { UserCommand } from '../../types/index.js';
import { deposit, withdraw, getBalance } from '../../services/economy.service.js';
import { successEmbed, errorEmbed } from '../../ui/embeds.js';
import { formatCoins } from '../../utils/format.js';

export const bankCmd: UserCommand = {
  name: 'bank',
  aliases: ['بنك'],
  description: 'إدارة البنك: bank deposit/withdraw <amount>',
  async execute({ message, args }) {
    if (!message.guild) return;
    const action = (args[0] ?? '').toLowerCase();
    const amount = BigInt(args[1] ?? '0');
    if ((action !== 'deposit' && action !== 'withdraw') || amount <= 0n) {
      const { balance, bank } = await getBalance(message.author.id, message.guild.id);
      await message.reply({
        embeds: [errorEmbed('استخدام', `bank deposit <amount> أو bank withdraw <amount>\n\n👛 ${formatCoins(balance)} | 🏦 ${formatCoins(bank)}`)],
      });
      return;
    }
    if (action === 'deposit') {
      await deposit(message.author.id, message.guild.id, amount);
      await message.reply({ embeds: [successEmbed('إيداع', `أودعت ${formatCoins(amount)}`)] });
    } else {
      await withdraw(message.author.id, message.guild.id, amount);
      await message.reply({ embeds: [successEmbed('سحب', `سحبت ${formatCoins(amount)}`)] });
    }
  },
};
EOF

# ============================================================
#  src/commands/user/profile.ts
# ============================================================
cat > src/commands/user/profile.ts <<'EOF'
import type { UserCommand } from '../../types/index.js';
import { ensureUserGuild } from '../../database/repositories/userRepo.js';
import { baseEmbed } from '../../ui/embeds.js';
import { formatCoins, formatNumber } from '../../utils/format.js';
import { COLORS } from '../../config/constants.js';

export const profileCmd: UserCommand = {
  name: 'profile',
  aliases: ['me', 'ملفي'],
  description: 'ملفك الشخصي',
  async execute({ message }) {
    if (!message.guild) return;
    const target = message.mentions.users.first() ?? message.author;
    const ug = await ensureUserGuild(target.id, message.guild.id, target.username, message.guild.name);
    const embed = baseEmbed()
      .setColor(COLORS.PRIMARY)
      .setTitle(`👤 ${target.username}`)
      .setThumbnail(target.displayAvatarURL())
      .addFields(
        { name: '👛 المحفظة', value: formatCoins(ug.balance), inline: true },
        { name: '🏦 البنك', value: formatCoins(ug.bank), inline: true },
        { name: '⭐ المستوى', value: `${ug.level}`, inline: true },
        { name: '✨ XP', value: formatNumber(ug.xp), inline: true },
        { name: '🔥 streak', value: `${ug.streak}`, inline: true },
        { name: '🎮 ألعاب', value: `${ug.gamesPlayed} (فاز ${ug.gamesWon})`, inline: true },
      );
    await message.reply({ embeds: [embed] });
  },
};
EOF

# ============================================================
#  src/commands/user/top.ts
# ============================================================
cat > src/commands/user/top.ts <<'EOF'
import type { UserCommand } from '../../types/index.js';
import { topBalances } from '../../services/economy.service.js';
import { topLevels } from '../../services/level.service.js';
import { goldEmbed } from '../../ui/embeds.js';
import { formatCoins, formatNumber } from '../../utils/format.js';

export const topCmd: UserCommand = {
  name: 'top',
  aliases: ['leaderboard', 'الصدارة'],
  description: 'قائمة الصدارة: top [money|level]',
  async execute({ message, args }) {
    if (!message.guild) return;
    const kind = (args[0] ?? 'money').toLowerCase();
    if (kind === 'level' || kind === 'levels' || kind === 'xp') {
      const rows = await topLevels(message.guild.id, 10);
      const desc = rows.map((r, i) => `**${i + 1}.** ${r.user.username ?? 'Unknown'} — Lvl **${r.level}** (${formatNumber(r.xp)} XP)`).join('\n') || 'لا توجد بيانات';
      await message.reply({ embeds: [goldEmbed('🏆 الصدارة — المستوى', desc)] });
      return;
    }
    const rows = await topBalances(message.guild.id, 10);
    const desc = rows.map((r, i) => `**${i + 1}.** ${r.user.username ?? 'Unknown'} — ${formatCoins(r.balance)}`).join('\n') || 'لا توجد بيانات';
    await message.reply({ embeds: [goldEmbed('🏆 الصدارة — الأرصدة', desc)] });
  },
};
EOF

# ============================================================
#  src/commands/user/help.ts
# ============================================================
cat > src/commands/user/help.ts <<'EOF'
import type { UserCommand } from '../../types/index.js';
import { baseEmbed } from '../../ui/embeds.js';
import { COLORS } from '../../config/constants.js';

export const helpCmd: UserCommand = {
  name: 'help',
  aliases: ['مساعدة', 'commands'],
  description: 'قائمة الأوامر',
  async execute({ message }) {
    const embed = baseEmbed()
      .setColor(COLORS.PRIMARY)
      .setTitle('📖 أوامر NOVA')
      .setDescription('جميع الأوامر تُكتب مباشرة في قناة الألعاب (بدون بادئة).')
      .addFields(
        { name: '💰 الاقتصاد', value: '`balance` `daily` `weekly` `work` `pay @user` `bank deposit/withdraw` `profile` `top`', inline: false },
        { name: '🎮 الألعاب', value: '`coinflip` `dice` `slots` `roulette` `blackjack`', inline: false },
        { name: '💼 الأنشطة', value: '`fish` `hunt` `crime` `rob @user`', inline: false },
        { name: '⚙️ الإدارة', value: '`/setchannel` `/removechannel`', inline: false },
      );
    await message.reply({ embeds: [embed] });
  },
};
EOF

# ============================================================
#  src/events/ready.ts
# ============================================================
cat > src/events/ready.ts <<'EOF'
import type { NovaClient } from '../core/client.js';
import { logger } from '../utils/logger.js';

export function onReady(client: NovaClient): void {
  client.once('ready', () => {
    logger.info({ tag: client.user?.tag, guilds: client.guilds.cache.size }, '✅ NOVA is online');
    client.user?.setPresence({
      status: 'online',
      activities: [{ name: 'NOVA | economy & games', type: 0 }],
    });
  });
}
EOF

# ============================================================
#  src/events/messageCreate.ts
# ============================================================
cat > src/events/messageCreate.ts <<'EOF'
import type { NovaClient } from '../core/client.js';
import { handleOwnerMessage } from '../handlers/ownerHandler.js';
import { handleUserMessage } from '../handlers/messageHandler.js';

export function onMessage(client: NovaClient): void {
  client.on('messageCreate', async (message) => {
    if (message.author.bot) return;
    const handledByOwner = await handleOwnerMessage(client, message);
    if (handledByOwner) return;
    await handleUserMessage(client, message);
  });
}
EOF

# ============================================================
#  src/events/interactionCreate.ts
# ============================================================
cat > src/events/interactionCreate.ts <<'EOF'
import type { NovaClient } from '../core/client.js';
import { handleSlash } from '../handlers/slashHandler.js';
import { setchannelCmd } from '../commands/slash/setchannel.js';
import { removechannelCmd } from '../commands/slash/removechannel.js';
import { logger } from '../utils/logger.js';
import { errorEmbed } from '../ui/embeds.js';

export function onInteraction(client: NovaClient): void {
  client.on('interactionCreate', async (interaction) => {
    if (!interaction.isChatInputCommand()) return;
    try {
      await handleSlash(interaction, {
        setchannel: setchannelCmd,
        removechannel: removechannelCmd,
      });
    } catch (err) {
      logger.error({ err }, 'slash failed');
      const payload = { embeds: [errorEmbed('خطأ', 'حدث خطأ غير متوقع.')], ephemeral: true };
      if (interaction.replied || interaction.deferred) await interaction.followUp(payload).catch(() => undefined);
      else await interaction.reply(payload).catch(() => undefined);
    }
  });
}
EOF

# ============================================================
#  src/events/error.ts
# ============================================================
cat > src/events/error.ts <<'EOF'
import type { NovaClient } from '../core/client.js';
import { logger } from '../utils/logger.js';

export function onError(client: NovaClient): void {
  client.on('error', (err) => logger.error({ err }, 'client error'));
  client.on('warn', (msg) => logger.warn({ msg }, 'client warn'));
  process.on('unhandledRejection', (reason) => logger.error({ reason }, 'unhandled rejection'));
  process.on('uncaughtException', (err) => logger.fatal({ err }, 'uncaught exception'));
}
EOF

# ============================================================
#  src/bot.ts
# ============================================================
cat > src/bot.ts <<'EOF'
import { NovaClient } from './core/client.js';
import { env } from './config/env.js';
import { logger } from './utils/logger.js';

// events
import { onReady } from './events/ready.js';
import { onMessage } from './events/messageCreate.js';
import { onInteraction } from './events/interactionCreate.js';
import { onError } from './events/error.js';

// owner commands
import { giveCmd } from './commands/owner/give.js';
import { takeCmd } from './commands/owner/take.js';
import { setmoneyCmd } from './commands/owner/setmoney.js';
import { resetCmd } from './commands/owner/reset.js';
import { banCmd } from './commands/owner/ban.js';
import { unbanCmd } from './commands/owner/unban.js';
import { broadcastCmd } from './commands/owner/broadcast.js';
import { reloadCmd } from './commands/owner/reload.js';
import { statusCmd } from './commands/owner/status.js';

// user commands
import { balanceCmd } from './commands/user/balance.js';
import { dailyCmd } from './commands/user/daily.js';
import { weeklyCmd } from './commands/user/weekly.js';
import { workCmd } from './commands/user/work.js';
import { payCmd } from './commands/user/pay.js';
import { bankCmd } from './commands/user/bank.js';
import { profileCmd } from './commands/user/profile.js';
import { topCmd } from './commands/user/top.js';
import { helpCmd } from './commands/user/help.js';

// games
import { CoinflipGame } from './games/coinflip.js';
import { DiceGame } from './games/dice.js';
import { SlotsGame } from './games/slots.js';
import { RouletteGame } from './games/roulette.js';
import { BlackjackGame } from './games/blackjack.js';
import { RobGame } from './games/rob.js';
import { CrimeGame } from './games/crime.js';
import { FishingGame } from './games/fishing.js';
import { HuntingGame } from './games/hunting.js';

// slash
import { slashCommandsData } from './handlers/slashHandler.js';

export async function startBot(): Promise<void> {
  const client = new NovaClient();

  // تسجيل أوامر المالك
  for (const c of [giveCmd, takeCmd, setmoneyCmd, resetCmd, banCmd, unbanCmd, broadcastCmd, reloadCmd, statusCmd]) {
    client.ownerCommands.set(c.name, c);
    for (const a of c.aliases ?? []) client.ownerCommands.set(a, c);
  }

  // تسجيل أوامر المستخدم
  for (const c of [balanceCmd, dailyCmd, weeklyCmd, workCmd, payCmd, bankCmd, profileCmd, topCmd, helpCmd]) {
    client.userCommands.set(c.name, c);
    for (const a of c.aliases ?? []) client.userCommands.set(a, c);
  }

  // تسجيل الألعاب كأوامر
  const games = [
    new CoinflipGame(), new DiceGame(), new SlotsGame(),
    new RouletteGame(), new BlackjackGame(), new RobGame(),
    new CrimeGame(), new FishingGame(), new HuntingGame(),
  ];
  for (const g of games) {
    const cmd = {
      name: g.name,
      aliases: g.aliases,
      description: `لعبة ${g.name}`,
      execute: async ({ message, args }: { message: import('discord.js').Message; args: string[] }) => {
        const result = await g.play(message, args);
        await message.reply(result.message);
      },
    };
    client.userCommands.set(g.name, cmd);
    for (const a of g.aliases) client.userCommands.set(a, cmd);
  }

  // الأحداث
  onReady(client);
  onMessage(client);
  onInteraction(client);
  onError(client);

  // تسجيل Slash commands
  client.once('ready', async () => {
    try {
      if (env.CLIENT_ID) {
        await client.application?.commands.set(slashCommandsData, env.CLIENT_ID);
        logger.info('✅ Slash commands registered (global)');
      } else {
        for (const g of client.guilds.cache.values()) {
          await g.commands.set(slashCommandsData).catch(() => undefined);
        }
        logger.info('✅ Slash commands registered (per-guild fallback)');
      }
    } catch (err) {
      logger.error({ err }, 'Failed to register slash commands');
    }
  });

  await client.login(env.DISCORD_TOKEN);
}
EOF

# ============================================================
#  src/index.ts  (entry point — sharding-ready)
# ============================================================
cat > src/index.ts <<'EOF'
import { env } from './config/env.js';
import { logger } from './utils/logger.js';

async function main(): Promise<void> {
  if (env.SHARDING_ENABLED) {
    const { ShardingManager } = await import('discord.js');
    const manager = new ShardingManager('./dist/bot.js', {
      token: env.DISCORD_TOKEN,
      totalShards: 'auto',
      respawn: true,
    });
    manager.on('shardCreate', (shard) => logger.info({ id: shard.id }, 'shard created'));
    await manager.spawn();
    logger.info('🚀 ShardingManager started');
    return;
  }

  // single-process mode
  const { startBot } = await import('./bot.js');
  await startBot();
}

main().catch((err) => {
  logger.fatal({ err }, 'Fatal startup error');
  process.exit(1);
});

process.on('SIGINT', () => {
  logger.info('SIGINT received — shutting down');
  process.exit(0);
});
process.on('SIGTERM', () => {
  logger.info('SIGTERM received — shutting down');
  process.exit(0);
});
EOF

# ============================================================
#  prisma/seed.ts  (بيانات افتراضية)
# ============================================================
cat > prisma/seed.ts <<'EOF'
import { PrismaClient } from '@prisma/client';
const prisma = new PrismaClient();

const items = [
  { code: 'vip_role', name: 'VIP Role', description: 'رتبة VIP', emoji: '👑', price: 100000n, sellPrice: 50000n, type: 'ROLE' as const, rarity: 'LEGENDARY' as const },
  { code: 'lucky_charm', name: 'Lucky Charm', description: 'يجلب الحظ', emoji: '🍀', price: 5000n, sellPrice: 2000n, type: 'BOOSTER' as const, rarity: 'RARE' as const },
  { code: 'common_box', name: 'Common Box', description: 'صندوق عادي', emoji: '📦', price: 500n, sellPrice: 200n, type: 'LOOTBOX' as const, rarity: 'COMMON' as const },
  { code: 'epic_box', name: 'Epic Box', description: 'صندوق ملحمي', emoji: '🎁', price: 5000n, sellPrice: 2000n, type: 'LOOTBOX' as const, rarity: 'EPIC' as const },
];

const titles = [
  { code: 'newbie', name: 'Newbie', description: 'مبتدئ', emoji: '🐣', price: 0n, rarity: 'COMMON' as const },
  { code: 'pro', name: 'Pro', description: 'محترف', emoji: '🎯', price: 10000n, rarity: 'RARE' as const },
  { code: 'legend', name: 'Legend', description: 'أسطورة', emoji: '🌟', price: 100000n, rarity: 'LEGENDARY' as const },
];

const achievements = [
  { code: 'first_daily', name: 'First Daily', description: 'أول daily', emoji: '📅', xpReward: 10n, moneyReward: 100n },
  { code: 'rich_10k', name: 'Rich', description: 'امتلك 10,000', emoji: '💰', xpReward: 50n, moneyReward: 500n },
  { code: 'gambler', name: 'Gambler', description: 'العب 100 لعبة', emoji: '🎰', xpReward: 100n, moneyReward: 1000n },
];

async function main() {
  for (const i of items) {
    await prisma.item.upsert({ where: { code: i.code }, update: i, create: i });
  }
  for (const t of titles) {
    await prisma.title.upsert({ where: { code: t.code }, update: t, create: t });
  }
  for (const a of achievements) {
    await prisma.achievement.upsert({ where: { code: a.code }, update: a, create: a });
  }
  console.log('✅ Seed complete');
}

main().finally(() => prisma.$disconnect());
EOF

# ============================================================
#  README.md
# ============================================================
cat > README.md <<'MDEOF'
# 🌌 NOVA — Discord Games & Economy Bot

بوت ديسكورد للألعاب والاقتصاد بأداء عالٍ وأمان قوي، مبني بـ TypeScript + discord.js v14 + Prisma + PostgreSQL + Redis.

## ✨ الميزات
- **اقتصاد كامل**: رصيد، بنك، تحويلات بضريبة، daily/weekly، work.
- **9 ألعاب**: coinflip, dice, slots, roulette, blackjack, fish, hunt, crime, rob.
- **نظام المستويات و XP**.
- **قوائم صدارة** (رصيد + مستوى).
- **Rate limiting + AntiFraud + Audit Log**.
- **Sharding جاهز** (يُفعَّل بـ `SHARDING_ENABLED=true`).
- **أوامر المالك** ببادئة `*` فقط.
- **أوامر المستخدم** بدون أي بادئة (تُكتب مباشرة).
- **Slash commands**: `/setchannel` و `/removechannel` فقط.

## 🚀 التثبيت السريع
```bash
bash setup.sh
cd nova
cp .env.example .env
# حرّر .env وضع DISCORD_TOKEN و OWNER_ID
npm install
npx prisma generate
npx prisma migrate deploy
npm run build
npm start
MDEOF

# ============================================================
#  .env.example
# ============================================================
cat > .env.example <<'EOF'
DISCORD_TOKEN=
OWNER_ID=
DATABASE_URL=
REDIS_URL=
NODE_ENV=production
SHARDING_ENABLED=false
EOF

# ============================================================
#  .gitignore
# ============================================================
cat > .gitignore <<'EOF'
node_modules/
dist/
.env
*.log
logs/
.DS_Store
EOF

# ============================================================
#  أوامر الختام
# ============================================================
cd ..
chmod +x nova/setup.sh
echo ""
echo "==========================================="
echo "🎉 NOVA project created successfully!"
echo "==========================================="
echo ""
echo "Next steps:"
echo "  cd nova"
echo "  cp .env.example .env"
echo "  # ضع DISCORD_TOKEN و OWNER_ID في .env"
echo "  npm install"
echo "  npx prisma generate"
echo "  npx prisma migrate deploy"
echo "  npm run build"
echo "  npm start"
