using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.IO;
using System.Linq;
using System.Text;
using System.Windows.Forms;
using System.Web.Script.Serialization;

namespace WordRogue
{
    static class Program
    {
        [STAThread]
        static void Main()
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new GameForm());
        }
    }

    public class WordEntry
    {
        public string word;
        public string meaning;
        public int difficulty;
        public int frequencyRank;
        public string[] tags;
        public int seenCount;
        public int correctCount;
        public int wrongCount;
        public int deathCount;
        public int mastery;
        public int lastSeenRoom;
    }

    public class SaveData
    {
        public List<WordEntry> words;
        public int bestRoom;
        public int totalCorrect;
        public int totalWrong;
        public bool hasContinue;
        public int continueMode;
        public string continueModeName;
        public int continueRoom;
        public float continueHp;
        public float continueSpeed;
        public float continueDashCooldown;
        public float continueThrowSpeed;
        public float continuePickupRange;
        public float continueDefense;
        public float continueLuck;
        public int continuePiercingInkRooms;
        public int continueEchoScrollRooms;
        public int continueSpeedBoostRooms;
        public int continueThrowBoostRooms;
        public int continueDashBoostRooms;
        public int continuePickupBoostRooms;
        public float continueTempSpeedBonus;
        public float continueTempThrowBonus;
        public float continueTempDashBonus;
        public float continueTempPickupBonus;
    }

    enum GameState
    {
        Menu,
        Playing,
        RoomClear,
        RewardChoice,
        GameOver,
        Win,
        Paused
    }

    enum MonsterKind
    {
        Wanderer,
        Chaser,
        Dasher,
        Shield,
        Ghost
    }

    enum DropKind
    {
        Apple,
        Coffee,
        ShieldPotion,
        Ink,
        Boots,
        Feather,
        Gloves
    }

    enum RewardKind
    {
        Survival,
        MoveSpeed,
        Shield,
        ChestSpeed,
        ChestThrow,
        ChestEcho
    }

    struct Vec2
    {
        public float X;
        public float Y;

        public Vec2(float x, float y)
        {
            X = x;
            Y = y;
        }

        public float Length()
        {
            return (float)Math.Sqrt(X * X + Y * Y);
        }

        public Vec2 Normalized()
        {
            float len = Length();
            if (len < 0.001f) return new Vec2(0, 0);
            return new Vec2(X / len, Y / len);
        }

        public static Vec2 From(PointF p)
        {
            return new Vec2(p.X, p.Y);
        }

        public PointF ToPointF()
        {
            return new PointF(X, Y);
        }

        public static Vec2 operator +(Vec2 a, Vec2 b)
        {
            return new Vec2(a.X + b.X, a.Y + b.Y);
        }

        public static Vec2 operator -(Vec2 a, Vec2 b)
        {
            return new Vec2(a.X - b.X, a.Y - b.Y);
        }

        public static Vec2 operator *(Vec2 a, float s)
        {
            return new Vec2(a.X * s, a.Y * s);
        }
    }

    class Player
    {
        public Vec2 Pos;
        public float Radius = 18;
        public float Hp = 100;
        public float MaxHp = 100;
        public float Speed = 245;
        public float DashCooldown = 1.2f;
        public float DashTimer = 0;
        public float ThrowSpeed = 610;
        public float PickupRange = 84;
        public float Defense = 0;
        public float MemoryBonus = 0;
        public float Luck = 0;
        public float Invulnerable = 0;
        public float SpeedBoost = 0;
        public float ShieldTime = 0;
        public bool PiercingInk = false;
        public bool EchoScroll = false;
        public string HeldMeaning = "";
    }

    class Monster
    {
        public WordEntry Entry;
        public Vec2 Pos;
        public Vec2 Vel;
        public float Radius;
        public float Hp;
        public float MaxHp;
        public MonsterKind Kind;
        public float ThinkTimer;
        public float RageTimer;
        public float DashWindup;
        public float ShootTimer;
        public bool FacingRight;
        public bool ShieldUp;
        public bool FromMistake;
    }

    class MeaningToken
    {
        public string Meaning;
        public Vec2 Pos;
        public bool CorrectForRoom;
        public float GlowTimer;
    }

    class Projectile
    {
        public string Meaning;
        public Vec2 Pos;
        public Vec2 Vel;
        public float Life;
        public bool Piercing;
        public bool Universal;
        public bool ReturnOnMiss;
        public HashSet<Monster> Hit;

        public Projectile()
        {
            Hit = new HashSet<Monster>();
        }
    }

    class EnemyProjectile
    {
        public Vec2 Pos;
        public Vec2 Vel;
        public float Life;
        public float Damage;
    }

    class Drop
    {
        public DropKind Kind;
        public Vec2 Pos;
        public float Life = 16;
    }

    class RewardCard
    {
        public RewardKind Kind;
        public string Category;
        public string Title;
        public string Description;
        public float Value;
    }

    class Chest
    {
        public Vec2 Pos;
        public bool Opened;
    }

    class Obstacle
    {
        public RectangleF Bounds;
        public string Kind;
        public int SpriteIndex;
        public Color Fill;
        public Color Stroke;
    }

    class FloatingText
    {
        public string Text;
        public Vec2 Pos;
        public float Life;
        public Color Color;
    }

    class Theme
    {
        public string Name;
        public Color Floor;
        public Color Wall;
        public Color Accent;

        public Theme(string name, Color floor, Color wall, Color accent)
        {
            Name = name;
            Floor = floor;
            Wall = wall;
            Accent = accent;
        }
    }

    class GameForm : Form
    {
        const int W = 1280;
        const int H = 720;
        const float Dt = 1f / 60f;

        readonly Random rng;
        readonly Timer timer;
        readonly HashSet<Keys> keys;
        readonly Font uiFont;
        readonly Font smallFont;
        readonly Font titleFont;
        readonly Font wordFont;
        readonly Font chineseFont;
        Image charactersSheet;
        Image heroGunActionsSheet;
        Image heroDirectionsSheet;
        Image heroWalkSheet;
        Image weaponAmmoSheet;
        Image obstaclesSheet;
        Rectangle[] obstacleSpriteSources;
        bool[] obstacleSpriteVisible;
        Image itemsSheet;
        Image tilesSheet;
        Image[] themeBackgrounds;

        Player player;
        GameState state;
        GameState previousState;
        List<WordEntry> allWords;
        List<WordEntry> bankWords;
        List<Monster> monsters;
        List<MeaningToken> meanings;
        List<Projectile> projectiles;
        List<EnemyProjectile> enemyProjectiles;
        List<Drop> drops;
        List<RewardCard> rewardCards;
        List<FloatingText> floatingTexts;
        List<Chest> chests;
        List<Obstacle> obstacles;
        List<WordEntry> runWords;
        List<string> roomLog;
        List<Theme> themes;
        SaveData saveData;
        PointF mouse;
        Vec2 lastMoveDir;
        int room;
        int combo;
        int streakWrong;
        int correctHits;
        int wrongHits;
        int collisions;
        float roomTime;
        float clearDelay;
        float roomDifficultyScale;
        int speedBoostRooms;
        int throwBoostRooms;
        int dashBoostRooms;
        int pickupBoostRooms;
        int piercingInkRooms;
        int echoScrollRooms;
        float tempSpeedBonus;
        float tempThrowBonus;
        float tempDashBonus;
        float tempPickupBonus;
        float walkAnimTime;
        float dashAnimTime;
        float fireAnimTime;
        int selectedMode;
        int playerFacing;
        string selectedModeName;
        string message;
        bool showBook;
        bool mouseLeftDown;
        bool customCursorHidden;
        bool isFullscreen;
        Rectangle windowedBounds;
        FormBorderStyle windowedBorderStyle;
        bool windowedMaximizeBox;
        float renderScale;
        float renderOffsetX;
        float renderOffsetY;
        string baseDir;

        public GameForm()
        {
            Text = "词域探险 - Word Realm Roguelike";
            ClientSize = new Size(W, H);
            FormBorderStyle = FormBorderStyle.FixedSingle;
            MaximizeBox = false;
            DoubleBuffered = true;
            KeyPreview = true;
            windowedBorderStyle = FormBorderStyle;
            windowedMaximizeBox = MaximizeBox;
            renderScale = 1f;

            rng = new Random();
            keys = new HashSet<Keys>();
            monsters = new List<Monster>();
            meanings = new List<MeaningToken>();
            projectiles = new List<Projectile>();
            enemyProjectiles = new List<EnemyProjectile>();
            drops = new List<Drop>();
            rewardCards = new List<RewardCard>();
            floatingTexts = new List<FloatingText>();
            chests = new List<Chest>();
            obstacles = new List<Obstacle>();
            runWords = new List<WordEntry>();
            roomLog = new List<string>();

            uiFont = new Font("Microsoft YaHei UI", 12, FontStyle.Regular);
            smallFont = new Font("Microsoft YaHei UI", 9, FontStyle.Regular);
            titleFont = new Font("Microsoft YaHei UI", 27, FontStyle.Bold);
            wordFont = new Font("Segoe UI", 12, FontStyle.Bold);
            chineseFont = new Font("Microsoft YaHei UI", 12, FontStyle.Bold);

            baseDir = AppDomain.CurrentDomain.BaseDirectory;
            LoadArtAssets();
            themes = BuildThemes();
            saveData = LoadSave();
            allWords = LoadWords();
            if (saveData == null) saveData = new SaveData();
            if (saveData.words == null) saveData.words = new List<WordEntry>();
            if (allWords == null || allWords.Count == 0) allWords = DefaultWords();
            MergeSavedStats();
            state = GameState.Menu;
            selectedMode = 2;
            selectedModeName = "简单 / 高中词汇";
            message = "选择难度后开始探险";
            mouse = new PointF(W / 2, H / 2);
            lastMoveDir = new Vec2(0, 1);

            timer = new Timer();
            timer.Interval = 16;
            timer.Tick += delegate { TickGame(); };
            timer.Start();

            KeyDown += OnKeyDown;
            KeyUp += OnKeyUp;
            MouseMove += delegate(object sender, MouseEventArgs e) { mouse = ClientToGame(e.Location); };
            MouseDown += OnMouseDown;
            MouseUp += delegate(object sender, MouseEventArgs e) { if (e.Button == MouseButtons.Left) mouseLeftDown = false; };
        }

        List<Theme> BuildThemes()
        {
            List<Theme> list = new List<Theme>();
            list.Add(new Theme("新手森林", Color.FromArgb(33, 62, 45), Color.FromArgb(19, 36, 31), Color.FromArgb(118, 184, 98)));
            list.Add(new Theme("办公废墟", Color.FromArgb(58, 61, 66), Color.FromArgb(32, 34, 39), Color.FromArgb(224, 175, 92)));
            list.Add(new Theme("校园图书馆", Color.FromArgb(58, 48, 75), Color.FromArgb(33, 28, 48), Color.FromArgb(154, 133, 201)));
            list.Add(new Theme("科技实验室", Color.FromArgb(35, 63, 73), Color.FromArgb(20, 37, 44), Color.FromArgb(74, 189, 198)));
            list.Add(new Theme("商业矿井", Color.FromArgb(72, 58, 42), Color.FromArgb(40, 32, 27), Color.FromArgb(227, 188, 93)));
            list.Add(new Theme("学术神殿", Color.FromArgb(51, 53, 75), Color.FromArgb(28, 31, 48), Color.FromArgb(220, 219, 166)));
            list.Add(new Theme("旅行港口", Color.FromArgb(35, 73, 86), Color.FromArgb(22, 43, 54), Color.FromArgb(106, 177, 221)));
            list.Add(new Theme("情绪洞穴", Color.FromArgb(74, 45, 58), Color.FromArgb(42, 27, 36), Color.FromArgb(228, 122, 139)));
            return list;
        }

        void LoadArtAssets()
        {
            heroGunActionsSheet = LoadAssetImage("hero_gun_actions.png");
            heroWalkSheet = LoadAssetImage("hero_walk.png");
            weaponAmmoSheet = LoadAssetImage("weapon_ammo.png");
            heroDirectionsSheet = LoadAssetImage("hero_directions.png");
            charactersSheet = LoadAssetImage("characters_monsters.png");
            obstaclesSheet = LoadAssetImage("theme_obstacles.png");
            BuildObstacleSpriteSources();
            itemsSheet = LoadAssetImage("items_projectiles_chests.png");
            tilesSheet = LoadAssetImage("theme_tiles_walls.png");
            LoadThemeBackgrounds();
        }

        Image LoadAssetImage(string name)
        {
            string path = Path.Combine(baseDir, "assets", "runtime", name);
            if (!File.Exists(path))
            {
                path = Path.Combine(Directory.GetCurrentDirectory(), "assets", "runtime", name);
            }
            if (!File.Exists(path))
            {
                path = Path.Combine(baseDir, "assets", "generated", name);
            }
            if (!File.Exists(path))
            {
                path = Path.Combine(Directory.GetCurrentDirectory(), "assets", "generated", name);
            }
            try
            {
                if (File.Exists(path)) return Image.FromFile(path);
            }
            catch
            {
            }
            return null;
        }

        void LoadThemeBackgrounds()
        {
            themeBackgrounds = new Image[8];
            string[] names = new string[]
            {
                "forest.jpg",
                "office.jpg",
                "library.jpg",
                "lab.jpg",
                "business_mine.jpg",
                "academic_temple.jpg",
                "travel_port.jpg",
                "emotion_cave.jpg"
            };
            for (int i = 0; i < names.Length; i++)
            {
                themeBackgrounds[i] = LoadBackgroundImage(names[i]);
            }
        }

        Image LoadBackgroundImage(string name)
        {
            string path = Path.Combine(baseDir, "assets", "runtime", "backgrounds", name);
            if (!File.Exists(path))
            {
                path = Path.Combine(Directory.GetCurrentDirectory(), "assets", "runtime", "backgrounds", name);
            }
            try
            {
                if (File.Exists(path)) return Image.FromFile(path);
            }
            catch
            {
            }
            return null;
        }

        Rectangle AtlasCell(Image image, int cols, int rows, int index)
        {
            int cw = image.Width / cols;
            int ch = image.Height / rows;
            int col = index % cols;
            int row = index / cols;
            return new Rectangle(col * cw, row * ch, cw, ch);
        }

        void BuildObstacleSpriteSources()
        {
            obstacleSpriteSources = new Rectangle[8];
            obstacleSpriteVisible = new bool[8];
            if (obstaclesSheet == null) return;

            using (Bitmap bitmap = new Bitmap(obstaclesSheet))
            {
                for (int i = 0; i < obstacleSpriteSources.Length; i++)
                {
                    Rectangle cell = AtlasCell(obstaclesSheet, 4, 2, i);
                    Rectangle crop;
                    bool visible = TryFindOpaqueBounds(bitmap, cell, out crop);
                    obstacleSpriteSources[i] = visible ? crop : cell;
                    obstacleSpriteVisible[i] = visible;
                }
            }
        }

        bool TryFindOpaqueBounds(Bitmap bitmap, Rectangle cell, out Rectangle bounds)
        {
            int minX = cell.Right;
            int minY = cell.Bottom;
            int maxX = cell.Left - 1;
            int maxY = cell.Top - 1;
            for (int y = cell.Top; y < cell.Bottom; y++)
            {
                for (int x = cell.Left; x < cell.Right; x++)
                {
                    Color pixel = bitmap.GetPixel(x, y);
                    if (pixel.A <= 12) continue;
                    if (x < minX) minX = x;
                    if (y < minY) minY = y;
                    if (x > maxX) maxX = x;
                    if (y > maxY) maxY = y;
                }
            }

            if (maxX < minX || maxY < minY)
            {
                bounds = cell;
                return false;
            }

            bounds = Rectangle.FromLTRB(minX, minY, maxX + 1, maxY + 1);
            return true;
        }

        void DrawAtlasCell(Graphics g, Image image, int cols, int rows, int index, RectangleF dest)
        {
            if (image == null) return;
            Rectangle src = AtlasCell(image, cols, rows, index);
            g.DrawImage(image, dest, src, GraphicsUnit.Pixel);
        }

        void DrawAtlasSourceKeepAspect(Graphics g, Image image, Rectangle src, RectangleF bounds)
        {
            if (image == null) return;
            RectangleF dest = AspectFitRect(src, bounds);
            g.DrawImage(image, dest, src, GraphicsUnit.Pixel);
        }

        void DrawAtlasCellKeepAspect(Graphics g, Image image, int cols, int rows, int index, RectangleF bounds)
        {
            DrawAtlasCellKeepAspect(g, image, cols, rows, index, bounds, false);
        }

        void DrawAtlasCellKeepAspect(Graphics g, Image image, int cols, int rows, int index, RectangleF bounds, bool mirrorX)
        {
            if (image == null) return;
            Rectangle src = AtlasCell(image, cols, rows, index);
            RectangleF dest = AspectFitRect(src, bounds);
            if (!mirrorX)
            {
                g.DrawImage(image, dest, src, GraphicsUnit.Pixel);
            }
            else
            {
                GraphicsState state = g.Save();
                g.TranslateTransform(dest.X + dest.Width / 2, dest.Y + dest.Height / 2);
                g.ScaleTransform(-1, 1);
                g.DrawImage(image, new RectangleF(-dest.Width / 2, -dest.Height / 2, dest.Width, dest.Height), src, GraphicsUnit.Pixel);
                g.Restore(state);
            }
        }

        RectangleF AspectFitRect(Rectangle src, RectangleF bounds)
        {
            float scale = Math.Min(bounds.Width / src.Width, bounds.Height / src.Height);
            float width = src.Width * scale;
            float height = src.Height * scale;
            return new RectangleF(bounds.X + (bounds.Width - width) / 2, bounds.Y + (bounds.Height - height) / 2, width, height);
        }

        void DrawAtlasCentered(Graphics g, Image image, int cols, int rows, int index, Vec2 center, float width, float height)
        {
            DrawAtlasCellKeepAspect(g, image, cols, rows, index, new RectangleF(center.X - width / 2, center.Y - height / 2, width, height));
        }

        void DrawAtlasCentered(Graphics g, Image image, int cols, int rows, int index, Vec2 center, float width, float height, bool mirrorX)
        {
            DrawAtlasCellKeepAspect(g, image, cols, rows, index, new RectangleF(center.X - width / 2, center.Y - height / 2, width, height), mirrorX);
        }

        void DrawRotatedAtlasCentered(Graphics g, Image image, int cols, int rows, int index, Vec2 center, float width, float height, float degrees)
        {
            if (image == null) return;
            Rectangle src = AtlasCell(image, cols, rows, index);
            float scale = Math.Min(width / src.Width, height / src.Height);
            float drawW = src.Width * scale;
            float drawH = src.Height * scale;
            GraphicsState state = g.Save();
            g.TranslateTransform(center.X, center.Y);
            g.RotateTransform(degrees);
            g.DrawImage(image, new RectangleF(-drawW / 2, -drawH / 2, drawW, drawH), src, GraphicsUnit.Pixel);
            g.Restore(state);
        }

        void OnKeyDown(object sender, KeyEventArgs e)
        {
            keys.Add(e.KeyCode);

            if (e.KeyCode == Keys.F11)
            {
                ToggleFullscreen();
                return;
            }

            if (state == GameState.Menu)
            {
                if (e.KeyCode == Keys.D1 || e.KeyCode == Keys.NumPad1) SelectDifficulty(2, "简单 / 高中词汇");
                if (e.KeyCode == Keys.D2 || e.KeyCode == Keys.NumPad2) SelectDifficulty(4, "普通 / 四六级词汇");
                if (e.KeyCode == Keys.D3 || e.KeyCode == Keys.NumPad3) SelectDifficulty(6, "困难 / 雅思词汇");
                if (e.KeyCode == Keys.Enter) StartSelectedGame();
                return;
            }

            if (e.KeyCode == Keys.Escape)
            {
                if (state == GameState.Playing)
                {
                    previousState = state;
                    state = GameState.Paused;
                }
                else if (state == GameState.Paused)
                {
                    state = previousState;
                }
                return;
            }

            if (state == GameState.GameOver || state == GameState.Win)
            {
                if (e.KeyCode == Keys.Enter) state = GameState.Menu;
                return;
            }

            if (state == GameState.RewardChoice)
            {
                if (e.KeyCode == Keys.D1 || e.KeyCode == Keys.NumPad1) ChooseReward(0);
                if (e.KeyCode == Keys.D2 || e.KeyCode == Keys.NumPad2) ChooseReward(1);
                if (e.KeyCode == Keys.D3 || e.KeyCode == Keys.NumPad3) ChooseReward(2);
                return;
            }

            if (state == GameState.Playing || state == GameState.RoomClear)
            {
                if (e.KeyCode == Keys.Tab) showBook = true;
                if (e.KeyCode == Keys.Space) TryDash();
                if (e.KeyCode == Keys.E) TryInteract();
                if (e.KeyCode == Keys.Q) UsePotion();
            }
        }

        void OnKeyUp(object sender, KeyEventArgs e)
        {
            keys.Remove(e.KeyCode);
            if (e.KeyCode == Keys.Tab) showBook = false;
        }

        void ToggleFullscreen()
        {
            if (!isFullscreen)
            {
                windowedBounds = Bounds;
                windowedBorderStyle = FormBorderStyle;
                windowedMaximizeBox = MaximizeBox;
                FormBorderStyle = FormBorderStyle.None;
                MaximizeBox = false;
                WindowState = FormWindowState.Maximized;
                isFullscreen = true;
            }
            else
            {
                WindowState = FormWindowState.Normal;
                FormBorderStyle = windowedBorderStyle;
                MaximizeBox = windowedMaximizeBox;
                if (windowedBounds.Width > 0 && windowedBounds.Height > 0) Bounds = windowedBounds;
                isFullscreen = false;
            }
            UpdateRenderViewport();
            mouse = ClientToGame(PointToClient(Cursor.Position));
            Invalidate();
        }

        void UpdateRenderViewport()
        {
            float sx = ClientSize.Width / (float)W;
            float sy = ClientSize.Height / (float)H;
            renderScale = Math.Max(0.1f, Math.Min(sx, sy));
            renderOffsetX = (ClientSize.Width - W * renderScale) / 2f;
            renderOffsetY = (ClientSize.Height - H * renderScale) / 2f;
        }

        PointF ClientToGame(Point point)
        {
            UpdateRenderViewport();
            float x = (point.X - renderOffsetX) / renderScale;
            float y = (point.Y - renderOffsetY) / renderScale;
            x = Clamp(x, 0, W);
            y = Clamp(y, 0, H);
            return new PointF(x, y);
        }

        void OnMouseDown(object sender, MouseEventArgs e)
        {
            if (e.Button != MouseButtons.Left) return;
            PointF gamePoint = ClientToGame(e.Location);
            Point location = Point.Round(gamePoint);
            if (state == GameState.Menu)
            {
                HandleMenuClick(location);
                return;
            }
            if (state == GameState.RewardChoice)
            {
                HandleRewardClick(location);
                return;
            }
            mouse = gamePoint;
            mouseLeftDown = true;
            if (state == GameState.Playing) FireHeldMeaning(false);
        }

        void SelectDifficulty(int maxDifficulty, string modeName)
        {
            selectedMode = maxDifficulty;
            selectedModeName = modeName;
        }

        void StartSelectedGame()
        {
            StartGame(selectedMode, selectedModeName);
        }

        void ContinueGame()
        {
            if (saveData == null || !saveData.hasContinue) return;
            int resumeRoom = Math.Max(1, saveData.continueRoom);
            StartGame(saveData.continueMode <= 0 ? 2 : saveData.continueMode, string.IsNullOrEmpty(saveData.continueModeName) ? "简单 / 高中词汇" : saveData.continueModeName, false);
            room = Math.Max(0, resumeRoom - 1);
            player.Hp = saveData.continueHp > 0 ? Math.Min(player.MaxHp, saveData.continueHp) : player.MaxHp;
            if (saveData.continueSpeed > 0) player.Speed = saveData.continueSpeed;
            if (saveData.continueDashCooldown > 0) player.DashCooldown = saveData.continueDashCooldown;
            if (saveData.continueThrowSpeed > 0) player.ThrowSpeed = saveData.continueThrowSpeed;
            if (saveData.continuePickupRange > 0) player.PickupRange = saveData.continuePickupRange;
            player.Defense = Math.Max(0, saveData.continueDefense);
            player.Luck = Math.Max(0, saveData.continueLuck);
            piercingInkRooms = Math.Max(0, saveData.continuePiercingInkRooms);
            echoScrollRooms = Math.Max(0, saveData.continueEchoScrollRooms);
            speedBoostRooms = Math.Max(0, saveData.continueSpeedBoostRooms);
            throwBoostRooms = Math.Max(0, saveData.continueThrowBoostRooms);
            dashBoostRooms = Math.Max(0, saveData.continueDashBoostRooms);
            pickupBoostRooms = Math.Max(0, saveData.continuePickupBoostRooms);
            tempSpeedBonus = Math.Max(0, saveData.continueTempSpeedBonus);
            tempThrowBonus = Math.Max(0, saveData.continueTempThrowBonus);
            tempDashBonus = Math.Max(0, saveData.continueTempDashBonus);
            tempPickupBonus = Math.Max(0, saveData.continueTempPickupBonus);
            player.PiercingInk = piercingInkRooms > 0;
            player.EchoScroll = echoScrollRooms > 0;
            StartRoom(false);
            message = "继续游戏：第 " + room + " 间";
        }

        void HandleMenuClick(Point location)
        {
            if (MenuDifficultyRect(0).Contains(location)) SelectDifficulty(2, "简单 / 高中词汇");
            else if (MenuDifficultyRect(1).Contains(location)) SelectDifficulty(4, "普通 / 四六级词汇");
            else if (MenuDifficultyRect(2).Contains(location)) SelectDifficulty(6, "困难 / 雅思词汇");
            else if (MenuStartRect().Contains(location)) StartSelectedGame();
            else if (MenuContinueRect().Contains(location) && saveData != null && saveData.hasContinue) ContinueGame();
        }

        void HandleRewardClick(Point location)
        {
            for (int i = 0; i < rewardCards.Count; i++)
            {
                if (RewardCardRect(i).Contains(location))
                {
                    ChooseReward(i);
                    return;
                }
            }
        }

        void StartGame(int maxDifficulty, string modeName)
        {
            StartGame(maxDifficulty, modeName, true);
        }

        void StartGame(int maxDifficulty, string modeName, bool enterFirstRoom)
        {
            selectedMode = maxDifficulty;
            selectedModeName = modeName;
            bankWords = allWords.Where(w => w.difficulty <= maxDifficulty).ToList();
            if (bankWords.Count == 0) bankWords = allWords.ToList();
            player = new Player();
            player.Pos = new Vec2(W / 2, H / 2 + 120);
            monsters.Clear();
            meanings.Clear();
            projectiles.Clear();
            enemyProjectiles.Clear();
            drops.Clear();
            chests.Clear();
            floatingTexts.Clear();
            obstacles.Clear();
            runWords.Clear();
            roomLog.Clear();
            room = 0;
            combo = 0;
            streakWrong = 0;
            correctHits = 0;
            wrongHits = 0;
            collisions = 0;
            roomDifficultyScale = 1f;
            message = "";
            state = GameState.Playing;
            speedBoostRooms = 0;
            throwBoostRooms = 0;
            dashBoostRooms = 0;
            pickupBoostRooms = 0;
            piercingInkRooms = 0;
            echoScrollRooms = 0;
            tempSpeedBonus = 0;
            tempThrowBonus = 0;
            tempDashBonus = 0;
            tempPickupBonus = 0;
            lastMoveDir = new Vec2(0, 1);
            playerFacing = 0;
            saveData.hasContinue = false;
            if (enterFirstRoom) StartRoom();
        }

        void StartRoom()
        {
            StartRoom(true);
        }

        void StartRoom(bool advancePowerups)
        {
            state = GameState.Playing;
            room++;
            if (advancePowerups) AdvanceRoomLimitedPowerups();
            monsters.Clear();
            meanings.Clear();
            projectiles.Clear();
            enemyProjectiles.Clear();
            drops.Clear();
            chests.Clear();
            floatingTexts.Clear();
            obstacles.Clear();
            roomLog.Clear();
            player.Pos = new Vec2(W / 2, H / 2 + 160);
            player.HeldMeaning = "";
            roomTime = 0;
            clearDelay = 0;
            correctHits = 0;
            wrongHits = 0;
            collisions = 0;
            showBook = false;
            GenerateObstacles();

            int targetCount = 3 + Math.Min(3, room / 2);
            if (roomDifficultyScale > 1.15f) targetCount++;
            if (selectedMode >= 4 && room > 3) targetCount++;
            if (selectedMode >= 6 && room > 5) targetCount++;
            targetCount = Math.Min(6, targetCount);
            targetCount = Math.Min(targetCount, Math.Max(1, bankWords.Count));

            List<WordEntry> chosen = PickRoomWords(targetCount);
            for (int i = 0; i < chosen.Count; i++)
            {
                WordEntry entry = chosen[i];
                entry.seenCount++;
                entry.lastSeenRoom = room;
                if (!runWords.Contains(entry)) runWords.Add(entry);

                Monster m = new Monster();
                m.Entry = entry;
                m.Radius = 31 + entry.difficulty * 1.8f;
                m.MaxHp = (room > 4 || entry.difficulty >= 4) ? 2 : 1;
                m.Hp = m.MaxHp;
                m.Kind = PickMonsterKind(entry);
                m.ShieldUp = m.Kind == MonsterKind.Shield;
                m.FromMistake = entry.wrongCount > entry.correctCount && rng.NextDouble() < 0.35;
                if (m.FromMistake) m.Kind = MonsterKind.Ghost;
                m.Pos = RandomFreePosition(m.Radius + 8);
                m.ThinkTimer = (float)rng.NextDouble() * 1.2f;
                m.ShootTimer = 1.4f + (float)rng.NextDouble() * 2.3f;
                monsters.Add(m);
            }

            SpawnMeaningTokens();
            if (rng.NextDouble() < 0.52) chests.Add(new Chest { Pos = RandomFreePosition(42) });
            message = "第 " + room + " 间：" + themes[(room - 1) % themes.Count].Name;
            if (targetCount > 3)
            {
                PrepareRewardCards();
                state = GameState.RewardChoice;
                message = "选择一张奖励卡后开始房间";
            }
            SaveContinueState();
        }

        void AdvanceRoomLimitedPowerups()
        {
            if (room <= 1) return;
            if (speedBoostRooms > 0 && --speedBoostRooms == 0 && tempSpeedBonus > 0)
            {
                player.Speed = Math.Max(120, player.Speed - tempSpeedBonus);
                tempSpeedBonus = 0;
                AddFloat("速度道具失效", player.Pos + new Vec2(-30, -36), Color.FromArgb(220, 220, 220));
            }
            if (throwBoostRooms > 0 && --throwBoostRooms == 0 && tempThrowBonus > 0)
            {
                player.ThrowSpeed = Math.Max(260, player.ThrowSpeed - tempThrowBonus);
                tempThrowBonus = 0;
                AddFloat("弹速道具失效", player.Pos + new Vec2(-30, -36), Color.FromArgb(220, 220, 220));
            }
            if (dashBoostRooms > 0 && --dashBoostRooms == 0 && tempDashBonus > 0)
            {
                player.DashCooldown += tempDashBonus;
                tempDashBonus = 0;
                AddFloat("轻羽失效", player.Pos + new Vec2(-30, -36), Color.FromArgb(220, 220, 220));
            }
            if (pickupBoostRooms > 0 && --pickupBoostRooms == 0 && tempPickupBonus > 0)
            {
                player.PickupRange = Math.Max(60, player.PickupRange - tempPickupBonus);
                tempPickupBonus = 0;
                AddFloat("磁力手套失效", player.Pos + new Vec2(-30, -36), Color.FromArgb(220, 220, 220));
            }
            if (piercingInkRooms > 0 && --piercingInkRooms == 0)
            {
                player.PiercingInk = false;
                AddFloat("穿透墨水失效", player.Pos + new Vec2(-30, -36), Color.FromArgb(220, 220, 220));
            }
            if (echoScrollRooms > 0 && --echoScrollRooms == 0)
            {
                player.EchoScroll = false;
                AddFloat("回声卷轴失效", player.Pos + new Vec2(-30, -36), Color.FromArgb(220, 220, 220));
            }
        }

        MonsterKind PickMonsterKind(WordEntry entry)
        {
            int roll = rng.Next(100);
            int tier = room + entry.difficulty;
            if (tier > 8 && roll < 18) return MonsterKind.Shield;
            if (tier > 6 && roll < 38) return MonsterKind.Dasher;
            if (tier > 4 && roll < 68) return MonsterKind.Chaser;
            return MonsterKind.Wanderer;
        }

        List<WordEntry> PickRoomWords(int count)
        {
            List<WordEntry> selected = new List<WordEntry>();
            List<WordEntry> pool = bankWords.ToList();
            for (int i = 0; i < count && pool.Count > 0; i++)
            {
                float total = 0;
                List<float> weights = new List<float>();
                foreach (WordEntry w in pool)
                {
                    float targetDifficulty = 1f + room * 0.42f;
                    float difficultyScore = 40f - Math.Abs(w.difficulty - targetDifficulty) * 9f;
                    float weight = Math.Max(6f, difficultyScore);
                    if (w.seenCount == 0) weight += 30f;
                    weight += w.wrongCount * 20f;
                    weight += w.deathCount * 50f;
                    weight -= w.mastery * 8f;
                    if (room - w.lastSeenRoom <= 3 && w.lastSeenRoom > 0) weight -= 30f;
                    if (w.correctCount >= 3 && w.wrongCount == 0) weight -= 18f;
                    if (weight < 2f) weight = 2f;
                    total += weight;
                    weights.Add(weight);
                }
                float pick = (float)rng.NextDouble() * total;
                float acc = 0;
                for (int j = 0; j < pool.Count; j++)
                {
                    acc += weights[j];
                    if (pick <= acc)
                    {
                        selected.Add(pool[j]);
                        pool.RemoveAt(j);
                        break;
                    }
                }
            }
            return selected;
        }

        void SpawnMeaningTokens()
        {
            HashSet<string> used = new HashSet<string>();
            foreach (Monster m in monsters)
            {
                int needed = RequiredHitsForMonster(m);
                for (int i = 0; i < needed; i++)
                {
                    AddMeaningToken(m.Entry.meaning, true);
                }
                used.Add(m.Entry.meaning);
            }

            int distractorCount = Math.Max(5, monsters.Count + 3);
            List<WordEntry> candidates = allWords.OrderBy(x => rng.Next()).ToList();
            foreach (WordEntry w in candidates)
            {
                if (used.Contains(w.meaning)) continue;
                bool sameTheme = false;
                foreach (Monster m in monsters)
                {
                    if (ShareTag(w, m.Entry)) sameTheme = true;
                }
                if (sameTheme || rng.NextDouble() < 0.35)
                {
                    AddMeaningToken(w.meaning, false);
                    used.Add(w.meaning);
                    distractorCount--;
                    if (distractorCount <= 0) break;
                }
            }
        }

        int RequiredHitsForMonster(Monster m)
        {
            int needed = (int)Math.Ceiling(m.MaxHp);
            if (m.ShieldUp) needed++;
            return Math.Max(1, needed);
        }

        bool ShareTag(WordEntry a, WordEntry b)
        {
            if (a.tags == null || b.tags == null) return false;
            foreach (string x in a.tags)
            {
                foreach (string y in b.tags)
                {
                    if (x == y) return true;
                }
            }
            return false;
        }

        MeaningToken AddMeaningToken(string meaning, bool correct)
        {
            return AddMeaningTokenAt(meaning, correct, FindMeaningTokenPosition(meaning, 100));
        }

        MeaningToken AddMeaningTokenAt(string meaning, bool correct, Vec2 pos)
        {
            if (!IsMeaningTokenPositionFree(meaning, pos, 30))
            {
                pos = FindMeaningTokenPosition(meaning, 70);
            }
            MeaningToken token = new MeaningToken();
            token.Meaning = meaning;
            token.Pos = pos;
            token.CorrectForRoom = correct;
            token.GlowTimer = correct && roomDifficultyScale < 0.92f ? 6f : 0f;
            meanings.Add(token);
            return token;
        }

        Vec2 FindMeaningTokenPosition(string meaning, float playerClearance)
        {
            for (int attempt = 0; attempt < 260; attempt++)
            {
                Vec2 p = new Vec2(80 + rng.Next(W - 160), 100 + rng.Next(H - 170));
                if (IsMeaningTokenPositionFree(meaning, p, playerClearance)) return p;
            }

            for (int y = 102; y < H - 70; y += 38)
            {
                for (int x = 72; x < W - 72; x += 54)
                {
                    Vec2 p = new Vec2(x, y);
                    if (IsMeaningTokenPositionFree(meaning, p, Math.Min(50, playerClearance))) return p;
                }
            }

            return RandomFreePosition(48);
        }

        Vec2 FindMeaningTokenPositionNear(string meaning, Vec2 center)
        {
            for (int i = 0; i < 80; i++)
            {
                double angle = rng.NextDouble() * Math.PI * 2;
                float distance = 42 + rng.Next(86);
                Vec2 candidate = center + new Vec2((float)Math.Cos(angle), (float)Math.Sin(angle)) * distance;
                if (IsMeaningTokenPositionFree(meaning, candidate, 24)) return candidate;
            }
            return FindMeaningTokenPosition(meaning, 50);
        }

        bool IsMeaningTokenPositionFree(string meaning, Vec2 pos, float playerClearance)
        {
            RectangleF bounds = MeaningTokenBounds(meaning, pos);
            if (bounds.Left < 44 || bounds.Right > W - 44) return false;
            if (bounds.Top < 78 || bounds.Bottom > H - 44) return false;

            if (DistancePointToRect(player.Pos, bounds) < player.Radius + playerClearance) return false;

            foreach (Obstacle obstacle in obstacles)
            {
                if (InflateRect(ObstacleCollisionBounds(obstacle), 8, 8).IntersectsWith(bounds)) return false;
            }

            foreach (Monster m in monsters)
            {
                if (DistancePointToRect(m.Pos, bounds) < m.Radius + 18) return false;
            }

            foreach (Chest chest in chests)
            {
                if (!chest.Opened && DistancePointToRect(chest.Pos, bounds) < 42) return false;
            }

            RectangleF padded = InflateRect(bounds, 10, 7);
            foreach (MeaningToken token in meanings)
            {
                if (padded.IntersectsWith(MeaningTokenBounds(token.Meaning, token.Pos))) return false;
            }

            return true;
        }

        RectangleF MeaningTokenBounds(string meaning, Vec2 pos)
        {
            float width = EstimateMeaningTextWidth(meaning) + 28;
            width = Clamp(width, 56, 220);
            return new RectangleF(pos.X - width / 2, pos.Y - 16, width, 32);
        }

        float EstimateMeaningTextWidth(string meaning)
        {
            if (string.IsNullOrEmpty(meaning)) return 28;
            float width = 0;
            foreach (char c in meaning)
            {
                if (c <= 127) width += 8.5f;
                else width += 15.5f;
            }
            return width;
        }

        Vec2 RandomFreePosition()
        {
            return RandomFreePosition(34);
        }

        Vec2 RandomFreePosition(float radius)
        {
            for (int attempt = 0; attempt < 80; attempt++)
            {
                Vec2 p = new Vec2(100 + rng.Next(W - 200), 110 + rng.Next(H - 210));
                if ((p - player.Pos).Length() < 130) continue;
                if (IsCircleBlocked(p, radius)) continue;
                bool ok = true;
                foreach (Monster m in monsters)
                {
                    if ((p - m.Pos).Length() < 90) ok = false;
                }
                if (ok) return p;
            }
            for (int x = 90; x < W - 90; x += 44)
            {
                for (int y = 110; y < H - 80; y += 44)
                {
                    Vec2 p = new Vec2(x, y);
                    if (!IsCircleBlocked(p, radius) && (p - player.Pos).Length() >= 90) return p;
                }
            }
            return player.Pos;
        }

        void GenerateObstacles()
        {
            obstacles.Clear();
            int themeIndex = (room - 1 + themes.Count) % themes.Count;
            int target = 6 + rng.Next(4) + Math.Min(3, room / 4);
            if (themeIndex == 7) target += 2;

            for (int attempt = 0; attempt < target * 18 && obstacles.Count < target; attempt++)
            {
                Obstacle obstacle = CreateRandomObstacle(themeIndex);
                if (!CanPlaceObstacle(obstacle)) continue;
                obstacles.Add(obstacle);
                if (!RoomNavigationIsValid())
                {
                    obstacles.RemoveAt(obstacles.Count - 1);
                }
            }
        }

        Obstacle CreateRandomObstacle(int themeIndex)
        {
            float width = 72 + rng.Next(70);
            float height = 44 + rng.Next(58);
            string kind = "障碍";
            int spriteIndex = themeIndex;
            Color fill = Color.FromArgb(100, 125, 95);
            Color stroke = Color.FromArgb(43, 54, 39);

            if (themeIndex == 0)
            {
                width = 46 + rng.Next(30);
                height = 46 + rng.Next(30);
                kind = "树木";
                fill = Color.FromArgb(70, 136, 68);
                stroke = Color.FromArgb(31, 73, 38);
            }
            else if (themeIndex == 1)
            {
                width = 96 + rng.Next(54);
                height = 42 + rng.Next(32);
                kind = "办公桌";
                fill = Color.FromArgb(118, 103, 82);
                stroke = Color.FromArgb(58, 49, 38);
            }
            else if (themeIndex == 2)
            {
                width = 54 + rng.Next(32);
                height = 118 + rng.Next(52);
                kind = "书架";
                fill = Color.FromArgb(112, 78, 105);
                stroke = Color.FromArgb(54, 38, 58);
            }
            else if (themeIndex == 3)
            {
                width = 108 + rng.Next(54);
                height = 48 + rng.Next(34);
                kind = "实验桌";
                fill = Color.FromArgb(70, 116, 126);
                stroke = Color.FromArgb(35, 66, 74);
            }
            else if (themeIndex == 4)
            {
                width = 70 + rng.Next(42);
                height = 78 + rng.Next(54);
                kind = "写字楼";
                fill = Color.FromArgb(132, 116, 91);
                stroke = Color.FromArgb(67, 56, 43);
            }
            else if (themeIndex == 5)
            {
                width = 58 + rng.Next(34);
                height = 118 + rng.Next(54);
                kind = "书架";
                fill = Color.FromArgb(111, 105, 137);
                stroke = Color.FromArgb(55, 53, 78);
            }
            else if (themeIndex == 6)
            {
                width = 96 + rng.Next(42);
                height = 48 + rng.Next(24);
                kind = "汽车";
                fill = Color.FromArgb(72, 137, 166);
                stroke = Color.FromArgb(33, 73, 92);
            }
            else if (themeIndex == 7)
            {
                width = 40 + rng.Next(34);
                height = 34 + rng.Next(30);
                kind = "花草";
                fill = Color.FromArgb(101, 154, 92);
                stroke = Color.FromArgb(57, 91, 53);
            }

            float x = 72 + rng.Next(Math.Max(1, (int)(W - 144 - width)));
            float y = 98 + rng.Next(Math.Max(1, (int)(H - 170 - height)));

            Obstacle obstacle = new Obstacle();
            obstacle.Bounds = new RectangleF(x, y, width, height);
            obstacle.Kind = kind;
            obstacle.SpriteIndex = spriteIndex;
            obstacle.Fill = fill;
            obstacle.Stroke = stroke;
            return obstacle;
        }

        bool CanPlaceObstacle(Obstacle candidate)
        {
            RectangleF candidateBounds = ObstacleCollisionBounds(candidate);
            RectangleF padded = InflateRect(candidateBounds, 30, 30);
            if (padded.Top < 78 || padded.Left < 42 || padded.Right > W - 42 || padded.Bottom > H - 48) return false;
            if (padded.Contains(player.Pos.ToPointF())) return false;
            if (DistancePointToRect(player.Pos, candidateBounds) < 150) return false;

            RectangleF startArea = new RectangleF(W / 2 - 95, H / 2 + 95, 190, 150);
            RectangleF centerArea = new RectangleF(W / 2 - 100, H / 2 - 80, 200, 160);
            if (candidateBounds.IntersectsWith(startArea) || candidateBounds.IntersectsWith(centerArea)) return false;

            foreach (Obstacle obstacle in obstacles)
            {
                if (padded.IntersectsWith(ObstacleCollisionBounds(obstacle))) return false;
            }
            return true;
        }

        bool RoomNavigationIsValid()
        {
            const int cell = 40;
            int cols = (W - 96) / cell;
            int rows = (H - 140) / cell;
            bool[,] blocked = new bool[cols, rows];
            int totalWalkable = 0;
            int startX = -1;
            int startY = -1;

            for (int x = 0; x < cols; x++)
            {
                for (int y = 0; y < rows; y++)
                {
                    Vec2 center = new Vec2(48 + x * cell + cell / 2, 82 + y * cell + cell / 2);
                    blocked[x, y] = IsCircleBlocked(center, 18);
                    if (!blocked[x, y])
                    {
                        totalWalkable++;
                        if (startX < 0 || (center - player.Pos).Length() < (new Vec2(48 + startX * cell + cell / 2, 82 + startY * cell + cell / 2) - player.Pos).Length())
                        {
                            startX = x;
                            startY = y;
                        }
                    }
                }
            }

            if (totalWalkable < cols * rows * 0.62f || startX < 0) return false;

            bool[,] seen = new bool[cols, rows];
            Queue<Point> queue = new Queue<Point>();
            queue.Enqueue(new Point(startX, startY));
            seen[startX, startY] = true;
            int visited = 0;

            while (queue.Count > 0)
            {
                Point p = queue.Dequeue();
                visited++;
                TryVisitCell(p.X + 1, p.Y, cols, rows, blocked, seen, queue);
                TryVisitCell(p.X - 1, p.Y, cols, rows, blocked, seen, queue);
                TryVisitCell(p.X, p.Y + 1, cols, rows, blocked, seen, queue);
                TryVisitCell(p.X, p.Y - 1, cols, rows, blocked, seen, queue);
            }

            return visited >= totalWalkable * 0.9f;
        }

        void TryVisitCell(int x, int y, int cols, int rows, bool[,] blocked, bool[,] seen, Queue<Point> queue)
        {
            if (x < 0 || y < 0 || x >= cols || y >= rows) return;
            if (blocked[x, y] || seen[x, y]) return;
            seen[x, y] = true;
            queue.Enqueue(new Point(x, y));
        }

        RectangleF InflateRect(RectangleF rect, float x, float y)
        {
            return new RectangleF(rect.X - x, rect.Y - y, rect.Width + x * 2, rect.Height + y * 2);
        }

        bool IsCircleBlocked(Vec2 center, float radius)
        {
            if (center.X - radius < 34 || center.X + radius > W - 34) return true;
            if (center.Y - radius < 66 || center.Y + radius > H - 34) return true;
            foreach (Obstacle obstacle in obstacles)
            {
                if (CircleIntersectsRect(center, radius, ObstacleCollisionBounds(obstacle))) return true;
            }
            return false;
        }

        RectangleF ObstacleCollisionBounds(Obstacle obstacle)
        {
            RectangleF bounds = ObstacleVisualBounds(obstacle);
            if (obstaclesSheet == null) return bounds;

            float insetX = Math.Min(6f, bounds.Width * 0.05f);
            float insetY = Math.Min(6f, bounds.Height * 0.05f);
            if (obstacle.Kind == "树木" || obstacle.Kind == "花草")
            {
                insetX = Math.Min(4f, bounds.Width * 0.04f);
                insetY = Math.Min(4f, bounds.Height * 0.04f);
            }
            return InflateRect(bounds, -insetX, -insetY);
        }

        RectangleF ObstacleVisualBounds(Obstacle obstacle)
        {
            RectangleF slot = ObstacleVisualSlot(obstacle);
            if (obstaclesSheet == null || obstacleSpriteVisible == null || !obstacleSpriteVisible[obstacle.SpriteIndex]) return slot;
            return AspectFitRect(obstacleSpriteSources[obstacle.SpriteIndex], slot);
        }

        RectangleF ObstacleVisualSlot(Obstacle obstacle)
        {
            RectangleF bounds = obstacle.Bounds;
            float minSide = Math.Max(1f, Math.Min(bounds.Width, bounds.Height));
            float scale = Math.Min(2.85f, Math.Max(1.45f, 112f / minSide));
            if (obstacle.Kind == "花草") scale = Math.Min(2.7f, Math.Max(1.7f, 92f / minSide));
            if (obstacle.Kind == "树木") scale = Math.Min(2.7f, Math.Max(1.55f, 104f / minSide));

            float width = bounds.Width * scale;
            float height = bounds.Height * scale;
            return new RectangleF(bounds.X + (bounds.Width - width) / 2, bounds.Y + (bounds.Height - height) / 2, width, height);
        }

        Vec2 MoveCircle(Vec2 start, Vec2 delta, float radius, out bool blocked)
        {
            blocked = false;
            int steps = Math.Max(1, (int)Math.Ceiling(delta.Length() / 12f));
            Vec2 step = delta * (1f / steps);
            Vec2 pos = start;
            for (int i = 0; i < steps; i++)
            {
                Vec2 nextX = new Vec2(pos.X + step.X, pos.Y);
                if (!IsCircleBlocked(nextX, radius))
                {
                    pos = nextX;
                }
                else
                {
                    blocked = true;
                }

                Vec2 nextY = new Vec2(pos.X, pos.Y + step.Y);
                if (!IsCircleBlocked(nextY, radius))
                {
                    pos = nextY;
                }
                else
                {
                    blocked = true;
                }
            }
            return pos;
        }

        void EnsurePlayerNotStuck()
        {
            if (!IsCircleBlocked(player.Pos, player.Radius)) return;
            Vec2 original = player.Pos;
            for (int ring = 1; ring <= 9; ring++)
            {
                float distance = ring * 18;
                for (int i = 0; i < 24; i++)
                {
                    double angle = Math.PI * 2 * i / 24.0;
                    Vec2 candidate = original + new Vec2((float)Math.Cos(angle), (float)Math.Sin(angle)) * distance;
                    if (!IsCircleBlocked(candidate, player.Radius))
                    {
                        player.Pos = candidate;
                        AddFloat("脱离卡位", player.Pos + new Vec2(-20, -30), Color.FromArgb(180, 230, 255));
                        return;
                    }
                }
            }
            player.Pos = new Vec2(W / 2, H / 2 + 160);
        }

        bool CircleIntersectsRect(Vec2 center, float radius, RectangleF rect)
        {
            float closestX = Clamp(center.X, rect.Left, rect.Right);
            float closestY = Clamp(center.Y, rect.Top, rect.Bottom);
            float dx = center.X - closestX;
            float dy = center.Y - closestY;
            return dx * dx + dy * dy <= radius * radius;
        }

        float DistancePointToRect(Vec2 point, RectangleF rect)
        {
            float dx = Math.Max(Math.Max(rect.Left - point.X, 0), point.X - rect.Right);
            float dy = Math.Max(Math.Max(rect.Top - point.Y, 0), point.Y - rect.Bottom);
            return (float)Math.Sqrt(dx * dx + dy * dy);
        }

        void TickGame()
        {
            if (state == GameState.Playing)
            {
                UpdatePlaying(Dt);
            }
            else if (state == GameState.RoomClear)
            {
                clearDelay -= Dt;
                UpdatePlayer(Dt);
                UpdateDrops(Dt);
                UpdateFloatingText(Dt);
                if (clearDelay <= 0) StartRoom();
            }
            Invalidate();
        }

        void UpdatePlaying(float dt)
        {
            roomTime += dt;
            UpdatePlayer(dt);
            UpdateMonsters(dt);
            UpdateProjectiles(dt);
            UpdateEnemyProjectiles(dt);
            UpdateDrops(dt);
            UpdateFloatingText(dt);

            if (monsters.Count == 0)
            {
                OnRoomCleared();
            }

            if (player.Hp <= 0)
            {
                foreach (Monster m in monsters)
                {
                    m.Entry.deathCount++;
                }
                state = GameState.GameOver;
                message = "探险失败。按 Enter 回到主菜单。";
                saveData.hasContinue = false;
                Save();
            }

            if (mouseLeftDown && player.HeldMeaning.Length > 0)
            {
                mouseLeftDown = false;
            }
        }

        void UpdatePlayer(float dt)
        {
            Vec2 input = GetMoveInput();
            if (Math.Abs(input.X) > 0.05f || Math.Abs(input.Y) > 0.05f)
            {
                lastMoveDir = input;
                walkAnimTime += dt;
                if (Math.Abs(input.X) > Math.Abs(input.Y))
                {
                    playerFacing = input.X < 0 ? 1 : 2;
                }
                else
                {
                    playerFacing = input.Y < 0 ? 3 : 0;
                }
            }
            else
            {
                walkAnimTime = 0;
                UpdateFacingFromAim(false);
            }
            float speed = player.Speed;
            if (player.SpeedBoost > 0) speed *= 1.35f;
            bool blocked;
            player.Pos = MoveCircle(player.Pos, input * speed * dt, player.Radius, out blocked);
            player.Pos.X = Clamp(player.Pos.X, 48, W - 48);
            player.Pos.Y = Clamp(player.Pos.Y, 78, H - 48);
            if (player.DashTimer > 0) player.DashTimer -= dt;
            if (player.Invulnerable > 0) player.Invulnerable -= dt;
            if (player.SpeedBoost > 0) player.SpeedBoost -= dt;
            if (player.ShieldTime > 0) player.ShieldTime -= dt;
            if (dashAnimTime > 0) dashAnimTime -= dt;
            if (fireAnimTime > 0) fireAnimTime -= dt;
            EnsurePlayerNotStuck();
        }

        Vec2 GetMoveInput()
        {
            Vec2 input = new Vec2(0, 0);
            if (keys.Contains(Keys.W) || keys.Contains(Keys.Up)) input.Y -= 1;
            if (keys.Contains(Keys.S) || keys.Contains(Keys.Down)) input.Y += 1;
            if (keys.Contains(Keys.A) || keys.Contains(Keys.Left)) input.X -= 1;
            if (keys.Contains(Keys.D) || keys.Contains(Keys.Right)) input.X += 1;
            return input.Normalized();
        }

        Vec2 FacingVector()
        {
            if (playerFacing == 1) return new Vec2(-1, 0);
            if (playerFacing == 2) return new Vec2(1, 0);
            if (playerFacing == 3) return new Vec2(0, -1);
            return new Vec2(0, 1);
        }

        void UpdateFacingFromAim(bool force)
        {
            Vec2 aim = (Vec2.From(mouse) - player.Pos).Normalized();
            if (!force && aim.Length() < 0.001f) return;
            if (Math.Abs(aim.X) > Math.Abs(aim.Y))
            {
                playerFacing = aim.X < 0 ? 1 : 2;
            }
            else
            {
                playerFacing = aim.Y < 0 ? 3 : 0;
            }
        }

        void UpdateMonsters(float dt)
        {
            for (int i = 0; i < monsters.Count; i++)
            {
                Monster m = monsters[i];
                if (m.RageTimer > 0) m.RageTimer -= dt;
                float speed = 55 + room * 3 + m.Entry.difficulty * 8;
                if (m.Kind == MonsterKind.Chaser) speed += 28;
                if (m.Kind == MonsterKind.Ghost) speed += 38;
                if (m.RageTimer > 0) speed *= 1.8f;
                if (roomDifficultyScale < 0.95f) speed *= 0.85f;
                if (roomDifficultyScale > 1.1f) speed *= 1.12f;

                Vec2 toPlayer = (player.Pos - m.Pos).Normalized();
                if (m.Kind == MonsterKind.Wanderer || m.Kind == MonsterKind.Shield)
                {
                    m.ThinkTimer -= dt;
                    if (m.ThinkTimer <= 0)
                    {
                        double a = rng.NextDouble() * Math.PI * 2;
                        m.Vel = new Vec2((float)Math.Cos(a), (float)Math.Sin(a));
                        m.ThinkTimer = 0.8f + (float)rng.NextDouble() * 1.4f;
                    }
                    if ((player.Pos - m.Pos).Length() < 180) m.Vel = (m.Vel * 0.75f + toPlayer * 0.25f).Normalized();
                }
                else if (m.Kind == MonsterKind.Chaser || m.Kind == MonsterKind.Ghost)
                {
                    m.Vel = (m.Vel * 0.82f + toPlayer * 0.18f).Normalized();
                }
                else if (m.Kind == MonsterKind.Dasher)
                {
                    if (m.DashWindup > 0)
                    {
                        m.DashWindup -= dt;
                        if (m.DashWindup <= 0) m.Vel = toPlayer * 4.2f;
                    }
                    else
                    {
                        m.ThinkTimer -= dt;
                        m.Vel = m.Vel * 0.94f;
                        if (m.ThinkTimer <= 0 && (player.Pos - m.Pos).Length() < 360)
                        {
                            m.DashWindup = 0.55f;
                            m.ThinkTimer = 2.2f;
                        }
                        else if (m.Vel.Length() < 0.1f)
                        {
                            m.Vel = toPlayer * 0.45f;
                        }
                    }
                }

                bool blocked;
                m.Pos = MoveCircle(m.Pos, m.Vel * speed * dt, m.Radius, out blocked);
                if (m.Vel.X > 0.05f) m.FacingRight = true;
                else if (m.Vel.X < -0.05f) m.FacingRight = false;
                if (blocked) m.Vel = m.Vel * -0.6f;
                if (m.Pos.X < 48 || m.Pos.X > W - 48) m.Vel.X *= -1;
                if (m.Pos.Y < 82 || m.Pos.Y > H - 52) m.Vel.Y *= -1;
                m.Pos.X = Clamp(m.Pos.X, 48, W - 48);
                m.Pos.Y = Clamp(m.Pos.Y, 82, H - 52);

                float touch = (m.Pos - player.Pos).Length();
                if (touch < m.Radius + player.Radius && player.Invulnerable <= 0)
                {
                    float damage = 12 + m.Entry.difficulty * 1.8f;
                    damage *= 1f - player.Defense;
                    if (player.ShieldTime > 0) damage *= 0.55f;
                    player.Hp -= damage;
                    player.Invulnerable = 0.55f;
                    collisions++;
                    AddFloat("-" + ((int)damage).ToString(), player.Pos + new Vec2(0, -24), Color.FromArgb(255, 115, 115));
                    Vec2 push = (player.Pos - m.Pos).Normalized();
                    if (push.Length() < 0.001f) push = new Vec2(1, 0);
                    bool pushBlocked;
                    player.Pos = MoveCircle(player.Pos, push * 34, player.Radius, out pushBlocked);
                    EnsurePlayerNotStuck();
                }

                UpdateMonsterShooting(m, dt);
            }
        }

        void UpdateMonsterShooting(Monster m, float dt)
        {
            if (!IsEliteMonster(m)) return;
            m.ShootTimer -= dt;
            float distance = (player.Pos - m.Pos).Length();
            if (m.ShootTimer > 0 || distance > 520 || distance < 70) return;
            if (!HasLineOfSight(m.Pos, player.Pos)) return;

            Vec2 dir = (player.Pos - m.Pos).Normalized();
            EnemyProjectile bullet = new EnemyProjectile();
            bullet.Pos = m.Pos + dir * (m.Radius + 12);
            bullet.Vel = dir * (210 + room * 8 + m.Entry.difficulty * 12);
            bullet.Life = 3.2f;
            bullet.Damage = 9 + m.Entry.difficulty * 1.6f;
            enemyProjectiles.Add(bullet);
            m.ShootTimer = Math.Max(1.25f, 3.3f - room * 0.08f - m.Entry.difficulty * 0.08f);
            AddFloat("精英弹幕", m.Pos + new Vec2(-22, -42), Color.FromArgb(255, 156, 116));
        }

        bool IsEliteMonster(Monster m)
        {
            return m.MaxHp >= 2 || m.Kind == MonsterKind.Shield || m.Entry.difficulty >= 5;
        }

        void UpdateProjectiles(float dt)
        {
            for (int i = projectiles.Count - 1; i >= 0; i--)
            {
                Projectile p = projectiles[i];
                p.Pos += p.Vel * dt;
                p.Life -= dt;
                bool remove = p.Life <= 0 || p.Pos.X < -40 || p.Pos.X > W + 40 || p.Pos.Y < -40 || p.Pos.Y > H + 40;
                if (!remove && ProjectileHitsObstacle(p))
                {
                    AddFloat("被障碍挡住", p.Pos + new Vec2(-18, -22), Color.FromArgb(230, 220, 150));
                    remove = true;
                }

                if (!remove)
                {
                    for (int j = monsters.Count - 1; j >= 0; j--)
                    {
                        Monster m = monsters[j];
                        if (p.Hit.Contains(m)) continue;
                        if ((p.Pos - m.Pos).Length() < m.Radius + 9)
                        {
                            p.Hit.Add(m);
                            bool effective = ResolveHit(p, m);
                            if (effective)
                            {
                                p.ReturnOnMiss = false;
                                if (!p.Piercing) remove = true;
                            }
                            else
                            {
                                ReturnProjectileMeaning(p);
                                remove = true;
                            }
                            if (monsters.Count == 0) break;
                        }
                    }
                }

                if (remove)
                {
                    ReturnProjectileMeaning(p);
                    projectiles.RemoveAt(i);
                }
            }
        }

        bool ProjectileHitsObstacle(Projectile p)
        {
            foreach (Obstacle obstacle in obstacles)
            {
                if (CircleIntersectsRect(p.Pos, 8, ObstacleCollisionBounds(obstacle))) return true;
            }
            return false;
        }

        void UpdateEnemyProjectiles(float dt)
        {
            for (int i = enemyProjectiles.Count - 1; i >= 0; i--)
            {
                EnemyProjectile bullet = enemyProjectiles[i];
                bullet.Pos += bullet.Vel * dt;
                bullet.Life -= dt;
                bool remove = bullet.Life <= 0 || bullet.Pos.X < -30 || bullet.Pos.X > W + 30 || bullet.Pos.Y < -30 || bullet.Pos.Y > H + 30;

                if (!remove && EnemyProjectileHitsObstacle(bullet))
                {
                    remove = true;
                }

                if (!remove && (bullet.Pos - player.Pos).Length() < player.Radius + 9 && player.Invulnerable <= 0)
                {
                    float damage = bullet.Damage * (1f - player.Defense);
                    if (player.ShieldTime > 0) damage *= 0.55f;
                    player.Hp -= damage;
                    player.Invulnerable = 0.42f;
                    collisions++;
                    AddFloat("弹幕 -" + ((int)damage).ToString(), player.Pos + new Vec2(-8, -34), Color.FromArgb(255, 132, 108));
                    remove = true;
                }

                if (remove) enemyProjectiles.RemoveAt(i);
            }
        }

        bool EnemyProjectileHitsObstacle(EnemyProjectile bullet)
        {
            foreach (Obstacle obstacle in obstacles)
            {
                if (CircleIntersectsRect(bullet.Pos, 8, ObstacleCollisionBounds(obstacle))) return true;
            }
            return false;
        }

        bool HasLineOfSight(Vec2 from, Vec2 to)
        {
            Vec2 delta = to - from;
            float len = delta.Length();
            if (len < 0.001f) return true;
            Vec2 step = delta.Normalized() * 18;
            int steps = (int)(len / 18);
            Vec2 p = from;
            for (int i = 0; i < steps; i++)
            {
                p += step;
                foreach (Obstacle obstacle in obstacles)
                {
                    if (CircleIntersectsRect(p, 8, ObstacleCollisionBounds(obstacle))) return false;
                }
            }
            return true;
        }

        bool ResolveHit(Projectile p, Monster m)
        {
            bool correct = p.Universal || p.Meaning == m.Entry.meaning;
            if (correct)
            {
                correctHits++;
                saveData.totalCorrect++;
                if (!p.Universal)
                {
                    m.Entry.correctCount++;
                    m.Entry.mastery = Math.Min(10, m.Entry.mastery + 1);
                }
                combo++;
                streakWrong = 0;

                if (m.ShieldUp)
                {
                    m.ShieldUp = false;
                    AddFloat(p.Universal ? "回声破盾" : "破盾", m.Pos + new Vec2(0, -36), Color.FromArgb(122, 211, 255));
                    m.RageTimer = 0.6f;
                    return true;
                }

                float damage = m.MaxHp >= 2 ? 1 : 99;
                if (combo >= 3)
                {
                    damage += 1;
                    player.Hp = Math.Min(player.MaxHp, player.Hp + 4);
                    AddFloat("连击+" + combo, player.Pos + new Vec2(0, -34), Color.FromArgb(148, 255, 166));
                }
                m.Hp -= damage;
                AddFloat(p.Universal ? "回声命中" : "正确：" + m.Entry.meaning, m.Pos + new Vec2(0, -38), Color.FromArgb(152, 245, 180));
                if (m.Hp <= 0) KillMonster(m);
                return true;
            }
            else
            {
                wrongHits++;
                saveData.totalWrong++;
                m.Entry.wrongCount++;
                m.Entry.mastery = Math.Max(0, m.Entry.mastery - 1);
                combo = 0;
                streakWrong++;
                m.RageTimer = 3f;
                m.Hp -= 0.15f;
                AddFloat("错配！" + m.Entry.word + " = " + m.Entry.meaning, m.Pos + new Vec2(0, -38), Color.FromArgb(255, 210, 94));
                if (streakWrong >= 2)
                {
                    roomDifficultyScale += 0.08f;
                    AddFloat("房间躁动", new Vec2(W / 2 - 40, 120), Color.FromArgb(255, 130, 130));
                    streakWrong = 0;
                }
                return false;
            }
        }

        void ReturnProjectileMeaning(Projectile p)
        {
            if (!p.ReturnOnMiss || p.Universal || p.Meaning.Length == 0 || monsters.Count == 0) return;
            bool correctForRemaining = monsters.Any(m => m.Entry.meaning == p.Meaning);
            MeaningToken token = AddMeaningToken(p.Meaning, correctForRemaining);
            p.ReturnOnMiss = false;
            AddFloat("词块刷新：" + p.Meaning, token.Pos + new Vec2(-22, -28), Color.FromArgb(236, 224, 132));
        }

        void KillMonster(Monster m)
        {
            AddFloat("记住 " + m.Entry.word, m.Pos + new Vec2(0, -58), Color.White);
            bool lastMonster = monsters.Count == 1;
            if (rng.NextDouble() < 0.16 + player.Luck)
            {
                DropKind kind = RandomDropKind();
                if (lastMonster) AutoCollectFinalDrop(kind, m.Pos);
                else SpawnDrop(kind, m.Pos);
            }
            monsters.Remove(m);
        }

        DropKind RandomDropKind()
        {
            Array values = Enum.GetValues(typeof(DropKind));
            return (DropKind)values.GetValue(rng.Next(values.Length));
        }

        void SpawnDrop(DropKind kind, Vec2 pos)
        {
            drops.Add(new Drop { Kind = kind, Pos = pos });
        }

        void AutoCollectFinalDrop(DropKind kind, Vec2 pos)
        {
            ApplyDrop(kind);
            AddFloat("自动拾取：" + DropDisplayName(kind), pos + new Vec2(-26, -30), Color.FromArgb(255, 226, 117));
        }

        string DropDisplayName(DropKind kind)
        {
            if (kind == DropKind.Apple) return "苹果";
            if (kind == DropKind.Coffee) return "咖啡";
            if (kind == DropKind.ShieldPotion) return "护盾";
            if (kind == DropKind.Ink) return "穿透墨水";
            if (kind == DropKind.Boots) return "风之靴";
            if (kind == DropKind.Feather) return "轻羽";
            if (kind == DropKind.Gloves) return "磁力手套";
            return "道具";
        }

        void UpdateDrops(float dt)
        {
            for (int i = drops.Count - 1; i >= 0; i--)
            {
                drops[i].Life -= dt;
                if ((drops[i].Pos - player.Pos).Length() < 34)
                {
                    ApplyDrop(drops[i].Kind);
                    drops.RemoveAt(i);
                    continue;
                }
                if (drops[i].Life <= 0) drops.RemoveAt(i);
            }
        }

        void UpdateFloatingText(float dt)
        {
            for (int i = floatingTexts.Count - 1; i >= 0; i--)
            {
                floatingTexts[i].Life -= dt;
                floatingTexts[i].Pos.Y -= 24 * dt;
                if (floatingTexts[i].Life <= 0) floatingTexts.RemoveAt(i);
            }
        }

        void TryDash()
        {
            if (player.DashTimer > 0 || (state != GameState.Playing && state != GameState.RoomClear)) return;
            Vec2 dir = GetMoveInput();
            if (dir.Length() < 0.001f) dir = lastMoveDir;
            if (dir.Length() < 0.001f) dir = FacingVector();
            bool blocked;
            player.Pos = MoveCircle(player.Pos, dir * 128, player.Radius, out blocked);
            player.Pos.X = Clamp(player.Pos.X, 48, W - 48);
            player.Pos.Y = Clamp(player.Pos.Y, 78, H - 48);
            player.DashTimer = player.DashCooldown;
            player.Invulnerable = 0.28f;
            dashAnimTime = 0.22f;
        }

        void TryInteract()
        {
            if (state == GameState.RoomClear)
            {
                clearDelay = 0;
                return;
            }

            MeaningToken best = null;
            float bestDist = player.PickupRange;
            foreach (MeaningToken token in meanings)
            {
                float d = (token.Pos - player.Pos).Length();
                if (d < bestDist)
                {
                    best = token;
                    bestDist = d;
                }
            }
            if (best != null)
            {
                if (player.HeldMeaning.Length > 0)
                {
                    DropHeldMeaning();
                }
                player.HeldMeaning = best.Meaning;
                meanings.Remove(best);
                AddFloat("拾取：" + best.Meaning, player.Pos + new Vec2(0, -30), Color.FromArgb(234, 239, 156));
                return;
            }

            foreach (Chest chest in chests)
            {
                if (!chest.Opened && (chest.Pos - player.Pos).Length() < 70)
                {
                    chest.Opened = true;
                    OpenChest();
                    return;
                }
            }
        }

        void DropHeldMeaning()
        {
            if (player.HeldMeaning.Length == 0) return;
            bool correctForRemaining = monsters.Any(m => m.Entry.meaning == player.HeldMeaning);
            Vec2 pos = FindDropPositionNearPlayer();
            AddMeaningTokenAt(player.HeldMeaning, correctForRemaining, pos);
            AddFloat("脱落：" + player.HeldMeaning, pos + new Vec2(-20, -30), Color.FromArgb(236, 224, 132));
            player.HeldMeaning = "";
        }

        Vec2 FindDropPositionNearPlayer()
        {
            return FindMeaningTokenPositionNear(player.HeldMeaning, player.Pos);
        }

        void UsePotion()
        {
            if (player.ShieldTime <= 0)
            {
                player.ShieldTime = 5f;
                AddFloat("护盾药剂", player.Pos + new Vec2(0, -34), Color.FromArgb(124, 205, 255));
            }
        }

        void FireHeldMeaning(bool echo)
        {
            if (player.HeldMeaning.Length == 0) return;
            Vec2 dir = GetAimDirection();
            if (dir.Length() < 0.001f) return;
            UpdateFacingFromAim(true);
            Projectile p = new Projectile();
            p.Meaning = player.HeldMeaning;
            p.Pos = GetMuzzlePosition(dir);
            p.Vel = dir * player.ThrowSpeed;
            p.Life = 1.55f;
            p.Piercing = player.PiercingInk;
            p.ReturnOnMiss = true;
            projectiles.Add(p);
            fireAnimTime = 0.16f;

            if (player.EchoScroll && !echo)
            {
                Projectile p2 = new Projectile();
                p2.Meaning = "回声";
                Vec2 side = new Vec2(-dir.Y, dir.X);
                p2.Pos = GetMuzzlePosition(dir) + side * 11;
                p2.Vel = (dir * 0.94f + side * 0.15f).Normalized() * (player.ThrowSpeed * 0.95f);
                p2.Life = 1.45f;
                p2.Piercing = player.PiercingInk;
                p2.Universal = true;
                p2.ReturnOnMiss = false;
                projectiles.Add(p2);
            }
            player.HeldMeaning = "";
        }

        Vec2 GetAimDirection()
        {
            Vec2 dir = (Vec2.From(mouse) - player.Pos).Normalized();
            if (dir.Length() < 0.001f) return new Vec2(1, 0);
            return dir;
        }

        Vec2 GetMuzzlePosition(Vec2 dir)
        {
            float recoil = fireAnimTime > 0 ? 5f : 0f;
            return player.Pos + dir * (42 - recoil) + new Vec2(0, -8);
        }

        void ApplyDrop(DropKind kind)
        {
            if (kind == DropKind.Apple)
            {
                player.Hp = Math.Min(player.MaxHp, player.Hp + player.MaxHp * 0.3f);
                AddFloat("苹果 +HP", player.Pos + new Vec2(0, -30), Color.FromArgb(160, 255, 174));
            }
            else if (kind == DropKind.Coffee)
            {
                player.SpeedBoost = 7f;
                AddFloat("咖啡 加速", player.Pos + new Vec2(0, -30), Color.FromArgb(234, 192, 126));
            }
            else if (kind == DropKind.ShieldPotion)
            {
                player.ShieldTime = 10f;
                AddFloat("护盾 10s", player.Pos + new Vec2(0, -30), Color.FromArgb(124, 205, 255));
            }
            else if (kind == DropKind.Ink)
            {
                GrantPiercingInk("穿透墨水 3间");
            }
            else if (kind == DropKind.Boots)
            {
                GrantSpeedBonus(18, "风之靴 3间");
            }
            else if (kind == DropKind.Feather)
            {
                GrantDashBonus(0.12f, "轻羽 3间");
            }
            else if (kind == DropKind.Gloves)
            {
                GrantPickupBonus(18, "磁力手套 3间");
            }
            SaveContinueState();
        }

        void OpenChest()
        {
            int choice = rng.Next(3);
            if (choice == 0)
            {
                GrantSpeedBonus(22, "宝箱：移速 3间");
                message = "宝箱：移动速度提升 3间";
            }
            else if (choice == 1)
            {
                GrantThrowBonus(90, "宝箱：弹速 3间");
                message = "宝箱：中文词义弹丸速度提升 3间";
            }
            else
            {
                GrantEchoScroll("宝箱：回声卷轴 3间");
                message = "宝箱：回声卷轴生效 3间";
            }
            SaveContinueState();
        }

        void GrantSpeedBonus(float amount, string label)
        {
            if (tempSpeedBonus <= 0)
            {
                player.Speed += amount;
                tempSpeedBonus = amount;
            }
            else if (amount > tempSpeedBonus)
            {
                player.Speed += amount - tempSpeedBonus;
                tempSpeedBonus = amount;
            }
            speedBoostRooms = 3;
            AddFloat(label, player.Pos + new Vec2(-30, -42), Color.FromArgb(159, 225, 255));
        }

        void GrantThrowBonus(float amount, string label)
        {
            if (tempThrowBonus <= 0)
            {
                player.ThrowSpeed += amount;
                tempThrowBonus = amount;
            }
            else if (amount > tempThrowBonus)
            {
                player.ThrowSpeed += amount - tempThrowBonus;
                tempThrowBonus = amount;
            }
            throwBoostRooms = 3;
            AddFloat(label, player.Pos + new Vec2(-30, -42), Color.FromArgb(255, 226, 117));
        }

        void GrantDashBonus(float amount, string label)
        {
            if (tempDashBonus <= 0)
            {
                player.DashCooldown = Math.Max(0.55f, player.DashCooldown - amount);
                tempDashBonus = amount;
            }
            else if (amount > tempDashBonus)
            {
                player.DashCooldown = Math.Max(0.55f, player.DashCooldown - (amount - tempDashBonus));
                tempDashBonus = amount;
            }
            dashBoostRooms = 3;
            AddFloat(label, player.Pos + new Vec2(-30, -42), Color.FromArgb(245, 245, 210));
        }

        void GrantPickupBonus(float amount, string label)
        {
            if (tempPickupBonus <= 0)
            {
                player.PickupRange += amount;
                tempPickupBonus = amount;
            }
            else if (amount > tempPickupBonus)
            {
                player.PickupRange += amount - tempPickupBonus;
                tempPickupBonus = amount;
            }
            pickupBoostRooms = 3;
            AddFloat(label, player.Pos + new Vec2(-30, -42), Color.FromArgb(255, 199, 120));
        }

        void GrantPiercingInk(string label)
        {
            player.PiercingInk = true;
            piercingInkRooms = 3;
            AddFloat(label, player.Pos + new Vec2(-30, -42), Color.FromArgb(188, 177, 255));
        }

        void GrantEchoScroll(string label)
        {
            player.EchoScroll = true;
            echoScrollRooms = 3;
            AddFloat(label, player.Pos + new Vec2(-30, -42), Color.FromArgb(255, 226, 117));
        }

        void PrepareRewardCards()
        {
            rewardCards.Clear();

            float hpPercent = 0.2f + (float)rng.NextDouble() * 0.3f;
            int hpText = (int)Math.Round(hpPercent * 100);
            rewardCards.Add(new RewardCard
            {
                Kind = RewardKind.Survival,
                Category = "生存类",
                Title = "生命补给",
                Description = "最大生命和当前生命 +" + hpText + "%",
                Value = hpPercent
            });

            if (rng.NextDouble() < 0.5)
            {
                rewardCards.Add(new RewardCard
                {
                    Kind = RewardKind.MoveSpeed,
                    Category = "防御类",
                    Title = "机动步伐",
                    Description = "移动速度永久 +14",
                    Value = 14
                });
            }
            else
            {
                rewardCards.Add(new RewardCard
                {
                    Kind = RewardKind.Shield,
                    Category = "防御类",
                    Title = "能量护盾",
                    Description = "减伤提升并获得护盾",
                    Value = 0.06f
                });
            }

            int item = rng.Next(3);
            if (item == 0)
            {
                rewardCards.Add(new RewardCard
                {
                    Kind = RewardKind.ChestSpeed,
                    Category = "道具类",
                    Title = "风箱补给",
                    Description = "获得宝箱移速道具 3间",
                    Value = 22
                });
            }
            else if (item == 1)
            {
                rewardCards.Add(new RewardCard
                {
                    Kind = RewardKind.ChestThrow,
                    Category = "道具类",
                    Title = "弹药校准",
                    Description = "获得宝箱弹速道具 3间",
                    Value = 90
                });
            }
            else
            {
                rewardCards.Add(new RewardCard
                {
                    Kind = RewardKind.ChestEcho,
                    Category = "道具类",
                    Title = "回声卷轴",
                    Description = "获得回声卷轴 3间",
                    Value = 0
                });
            }
        }

        void ChooseReward(int index)
        {
            if (state != GameState.RewardChoice || index < 0 || index >= rewardCards.Count) return;
            RewardCard card = rewardCards[index];
            ApplyReward(card);
            rewardCards.Clear();
            state = GameState.Playing;
            message = "奖励生效：" + card.Title;
            SaveContinueState();
        }

        void ApplyReward(RewardCard card)
        {
            if (card.Kind == RewardKind.Survival)
            {
                float gain = player.MaxHp * card.Value;
                player.MaxHp += gain;
                player.Hp = Math.Min(player.MaxHp, player.Hp + gain);
                AddFloat("生命 +" + (int)gain, player.Pos + new Vec2(-20, -42), Color.FromArgb(160, 255, 174));
            }
            else if (card.Kind == RewardKind.MoveSpeed)
            {
                player.Speed += card.Value;
                AddFloat("移速 +" + (int)card.Value, player.Pos + new Vec2(-20, -42), Color.FromArgb(159, 225, 255));
            }
            else if (card.Kind == RewardKind.Shield)
            {
                player.Defense = Math.Min(0.35f, player.Defense + card.Value);
                player.ShieldTime = Math.Max(player.ShieldTime, 12f);
                AddFloat("护盾强化", player.Pos + new Vec2(-20, -42), Color.FromArgb(124, 205, 255));
            }
            else if (card.Kind == RewardKind.ChestSpeed)
            {
                GrantSpeedBonus(card.Value, "奖励：移速 3间");
            }
            else if (card.Kind == RewardKind.ChestThrow)
            {
                GrantThrowBonus(card.Value, "奖励：弹速 3间");
            }
            else if (card.Kind == RewardKind.ChestEcho)
            {
                GrantEchoScroll("奖励：回声卷轴 3间");
            }
        }

        void OnRoomCleared()
        {
            float accuracy = (correctHits + wrongHits) == 0 ? 1f : (float)correctHits / (correctHits + wrongHits);
            if (accuracy >= 0.8f && collisions <= 1 && roomTime < 80)
            {
                roomDifficultyScale = Math.Min(1.35f, roomDifficultyScale + 0.08f);
                message = "清房漂亮：下一间更有挑战";
            }
            else if (accuracy < 0.5f || collisions >= 4 || roomTime > 100)
            {
                roomDifficultyScale = Math.Max(0.74f, roomDifficultyScale - 0.12f);
                player.Hp = Math.Min(player.MaxHp, player.Hp + 18);
                message = "系统降压：下间减少压迫并闪烁正确释义";
            }
            else
            {
                message = "房间清空。按 E 立刻进入下一间。";
            }

            if (runWords.Distinct().Count() >= bankWords.Count)
            {
                state = GameState.Win;
                message = "词库清空，通关！按 Enter 回到主菜单。";
                saveData.bestRoom = Math.Max(saveData.bestRoom, room);
                saveData.hasContinue = false;
                Save();
                return;
            }

            state = GameState.RoomClear;
            clearDelay = 2.2f;
            saveData.bestRoom = Math.Max(saveData.bestRoom, room);
            Save();
        }

        void AddFloat(string text, Vec2 pos, Color color)
        {
            FloatingText ft = new FloatingText();
            ft.Text = text;
            ft.Pos = pos;
            ft.Life = 1.35f;
            ft.Color = color;
            floatingTexts.Add(ft);
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            UpdateCursorVisibility();
            Graphics g = e.Graphics;
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.InterpolationMode = InterpolationMode.Bilinear;
            g.PixelOffsetMode = PixelOffsetMode.Half;
            g.TextRenderingHint = System.Drawing.Text.TextRenderingHint.ClearTypeGridFit;
            g.Clear(Color.Black);
            UpdateRenderViewport();

            GraphicsState renderState = g.Save();
            g.TranslateTransform(renderOffsetX, renderOffsetY);
            g.ScaleTransform(renderScale, renderScale);
            g.SetClip(new Rectangle(0, 0, W, H));

            if (state == GameState.Menu)
            {
                DrawMenu(g);
            }
            else
            {
                DrawGame(g);
                if (state == GameState.RewardChoice) DrawRewardChoice(g);
                if (state == GameState.Paused) DrawOverlayPanel(g, "暂停", "按 Esc 继续");
                if (state == GameState.GameOver) DrawEndScreen(g, "探险失败");
                if (state == GameState.Win) DrawEndScreen(g, "通关结算");
                if (showBook && (state == GameState.Playing || state == GameState.RoomClear)) DrawMemoryBook(g);
                if (state == GameState.Playing || state == GameState.RoomClear) DrawCrosshair(g);
            }

            g.Restore(renderState);
        }

        protected override void OnFormClosing(FormClosingEventArgs e)
        {
            if (state == GameState.Playing || state == GameState.RoomClear || state == GameState.Paused || state == GameState.RewardChoice)
            {
                SaveContinueState();
            }
            base.OnFormClosing(e);
        }

        protected override void OnFormClosed(FormClosedEventArgs e)
        {
            SetCustomCursorHidden(false);
            base.OnFormClosed(e);
        }

        void UpdateCursorVisibility()
        {
            bool shouldHide = state == GameState.Playing || state == GameState.RoomClear;
            SetCustomCursorHidden(shouldHide);
        }

        void SetCustomCursorHidden(bool hidden)
        {
            if (customCursorHidden == hidden) return;
            if (hidden) Cursor.Hide();
            else Cursor.Show();
            customCursorHidden = hidden;
        }

        void DrawCrosshair(Graphics g)
        {
            float x = mouse.X;
            float y = mouse.Y;
            using (Pen outer = new Pen(Color.FromArgb(230, 20, 24, 28), 3))
            using (Pen inner = new Pen(Color.FromArgb(245, 255, 232, 128), 1.5f))
            {
                g.DrawEllipse(outer, x - 8, y - 8, 16, 16);
                g.DrawLine(outer, x - 14, y, x - 10, y);
                g.DrawLine(outer, x + 10, y, x + 14, y);
                g.DrawLine(outer, x, y - 14, x, y - 10);
                g.DrawLine(outer, x, y + 10, x, y + 14);
                g.DrawEllipse(inner, x - 8, y - 8, 16, 16);
                g.DrawLine(inner, x - 14, y, x - 10, y);
                g.DrawLine(inner, x + 10, y, x + 14, y);
                g.DrawLine(inner, x, y - 14, x, y - 10);
                g.DrawLine(inner, x, y + 10, x, y + 14);
            }
        }

        void DrawMenu(Graphics g)
        {
            using (SolidBrush bg = new SolidBrush(Color.FromArgb(18, 22, 28)))
            {
                g.FillRectangle(bg, ClientRectangle);
            }
            DrawStars(g);
            DrawMenuPreview(g);
            using (SolidBrush b = new SolidBrush(Color.White))
            {
                DrawCentered(g, "词域探险", titleFont, b, 78);
            }
            using (SolidBrush b = new SolidBrush(Color.FromArgb(199, 214, 224)))
            {
                DrawCentered(g, "选择词库难度，然后开始一局单词地牢探险", uiFont, b, 132);
            }

            DrawDifficultyButton(g, 0, "简单", "高中词汇", "基础词优先，怪物压力较低", 2);
            DrawDifficultyButton(g, 1, "普通", "四六级词汇", "更高词汇难度，房间推进更快", 4);
            DrawDifficultyButton(g, 2, "困难", "雅思词汇", "高阶词、精英怪和动态压力更明显", 6);

            DrawStartButton(g);
            DrawContinueButton(g);

            using (SolidBrush b = new SolidBrush(Color.FromArgb(176, 190, 201)))
            {
                DrawCentered(g, "快捷键：1/2/3 选择难度，Enter 开始，F11 全屏", smallFont, b, 612);
                DrawCentered(g, "游戏内：WASD 移动  鼠标瞄准  左键发射  E 拾取  Space 闪避  Tab 记忆书", smallFont, b, 642);
            }
        }

        Rectangle MenuDifficultyRect(int index)
        {
            int width = 260;
            int height = 150;
            int gap = 26;
            int total = width * 3 + gap * 2;
            int x = W / 2 - total / 2 + index * (width + gap);
            return new Rectangle(x, 230, width, height);
        }

        Rectangle MenuStartRect()
        {
            return new Rectangle(W / 2 - 145, 420, 290, 58);
        }

        Rectangle MenuContinueRect()
        {
            return new Rectangle(W / 2 - 145, 492, 290, 52);
        }

        void DrawDifficultyButton(Graphics g, int index, string title, string subtitle, string description, int maxDifficulty)
        {
            Rectangle r = MenuDifficultyRect(index);
            bool selected = selectedMode == maxDifficulty;
            bool hover = r.Contains(Point.Round(mouse));
            Color fill = selected ? Color.FromArgb(63, 102, 82) : Color.FromArgb(37, 45, 56);
            if (hover && !selected) fill = Color.FromArgb(47, 57, 70);
            Color border = selected ? Color.FromArgb(145, 231, 146) : Color.FromArgb(85, 99, 116);

            using (GraphicsPath path = RoundedRect(r, 8))
            using (SolidBrush b = new SolidBrush(fill))
            using (Pen p = new Pen(border, selected ? 3 : 1))
            {
                g.FillPath(b, path);
                g.DrawPath(p, path);
            }

            using (SolidBrush b = new SolidBrush(Color.White))
            {
                DrawCenteredInRect(g, title, titleFont, b, new Rectangle(r.Left, r.Top + 20, r.Width, 42));
            }
            using (SolidBrush b = new SolidBrush(selected ? Color.FromArgb(192, 246, 185) : Color.FromArgb(225, 232, 238)))
            {
                DrawCenteredInRect(g, subtitle, chineseFont, b, new Rectangle(r.Left, r.Top + 70, r.Width, 26));
            }
            using (SolidBrush b = new SolidBrush(Color.FromArgb(181, 194, 204)))
            {
                DrawCenteredInRect(g, description, smallFont, b, new Rectangle(r.Left + 18, r.Top + 106, r.Width - 36, 30));
            }
        }

        void DrawStartButton(Graphics g)
        {
            Rectangle r = MenuStartRect();
            bool hover = r.Contains(Point.Round(mouse));
            Color fill = hover ? Color.FromArgb(236, 202, 103) : Color.FromArgb(222, 178, 72);
            using (GraphicsPath path = RoundedRect(r, 8))
            using (SolidBrush b = new SolidBrush(fill))
            using (Pen p = new Pen(Color.FromArgb(76, 50, 20), 2))
            {
                g.FillPath(b, path);
                g.DrawPath(p, path);
            }
            using (SolidBrush b = new SolidBrush(Color.FromArgb(35, 29, 18)))
            {
                DrawCenteredInRect(g, "开始新游戏", titleFont, b, r);
            }
            using (SolidBrush b = new SolidBrush(Color.FromArgb(213, 224, 231)))
            {
                DrawCentered(g, "当前选择：" + selectedModeName, uiFont, b, 560);
            }
        }

        void DrawContinueButton(Graphics g)
        {
            Rectangle r = MenuContinueRect();
            bool enabled = saveData != null && saveData.hasContinue;
            bool hover = enabled && r.Contains(Point.Round(mouse));
            Color fill = enabled ? (hover ? Color.FromArgb(95, 157, 199) : Color.FromArgb(67, 123, 164)) : Color.FromArgb(58, 65, 72);
            Color border = enabled ? Color.FromArgb(154, 212, 245) : Color.FromArgb(88, 96, 104);
            using (GraphicsPath path = RoundedRect(r, 8))
            using (SolidBrush b = new SolidBrush(fill))
            using (Pen p = new Pen(border, 2))
            {
                g.FillPath(b, path);
                g.DrawPath(p, path);
            }
            string label = enabled ? "继续游戏：第 " + saveData.continueRoom + " 间" : "继续游戏";
            using (SolidBrush b = new SolidBrush(enabled ? Color.White : Color.FromArgb(150, 160, 168)))
            {
                DrawCenteredInRect(g, label, chineseFont, b, r);
            }
        }

        void DrawMenuPreview(Graphics g)
        {
            using (SolidBrush floor = new SolidBrush(Color.FromArgb(26, 36, 43)))
            {
                g.FillRectangle(floor, 0, 0, W, H);
            }
            using (Pen grid = new Pen(Color.FromArgb(22, 255, 255, 255), 1))
            {
                for (int x = 0; x < W; x += 74) g.DrawLine(grid, x, 0, x, H);
                for (int y = 0; y < H; y += 74) g.DrawLine(grid, 0, y, W, y);
            }

            DrawPreviewMonster(g, 134, 528, "increase", Color.FromArgb(210, 83, 92));
            DrawPreviewMonster(g, 1060, 196, "strategy", Color.FromArgb(232, 117, 79));
            DrawPreviewMonster(g, 990, 548, "curious", Color.FromArgb(174, 111, 214));
            DrawPreviewToken(g, 216, 184, "增加");
            DrawPreviewToken(g, 960, 392, "策略");
            DrawPreviewToken(g, 404, 520, "好奇的");
        }

        void DrawPreviewMonster(Graphics g, int x, int y, string word, Color color)
        {
            using (SolidBrush shadow = new SolidBrush(Color.FromArgb(80, 0, 0, 0)))
            using (SolidBrush b = new SolidBrush(Color.FromArgb(150, color)))
            using (Pen p = new Pen(Color.FromArgb(80, 20, 24, 32), 3))
            {
                g.FillEllipse(shadow, x - 38, y + 26, 76, 16);
                g.FillEllipse(b, x - 42, y - 42, 84, 84);
                g.DrawEllipse(p, x - 42, y - 42, 84, 84);
            }
            SizeF s = g.MeasureString(word, wordFont);
            using (SolidBrush b = new SolidBrush(Color.FromArgb(210, 255, 255, 255)))
            {
                g.DrawString(word, wordFont, b, x - s.Width / 2, y - 11);
            }
        }

        void DrawPreviewToken(Graphics g, int x, int y, string text)
        {
            SizeF size = g.MeasureString(text, chineseFont);
            Rectangle r = new Rectangle((int)(x - size.Width / 2 - 14), y - 16, (int)(size.Width + 28), 32);
            using (GraphicsPath path = RoundedRect(r, 7))
            using (SolidBrush b = new SolidBrush(Color.FromArgb(160, 229, 170, 82)))
            using (Pen p = new Pen(Color.FromArgb(75, 50, 32), 2))
            {
                g.FillPath(b, path);
                g.DrawPath(p, path);
            }
            using (SolidBrush b = new SolidBrush(Color.FromArgb(42, 35, 23)))
            {
                g.DrawString(text, chineseFont, b, x - size.Width / 2, y - 11);
            }
        }

        void DrawStars(Graphics g)
        {
            Random fixedRng = new Random(7);
            using (SolidBrush b = new SolidBrush(Color.FromArgb(60, 255, 255, 255)))
            {
                for (int i = 0; i < 90; i++)
                {
                    int x = fixedRng.Next(W);
                    int y = fixedRng.Next(H);
                    g.FillEllipse(b, x, y, 2, 2);
                }
            }
        }

        void DrawGame(Graphics g)
        {
            Theme t = themes[(room - 1 + themes.Count) % themes.Count];
            if (!DrawThemeBackground(g))
            {
                using (SolidBrush b = new SolidBrush(t.Floor))
                {
                    g.FillRectangle(b, ClientRectangle);
                }
                using (SolidBrush wall = new SolidBrush(t.Wall))
                {
                    g.FillRectangle(wall, 0, 0, W, 58);
                    g.FillRectangle(wall, 0, H - 30, W, 30);
                    g.FillRectangle(wall, 0, 0, 28, H);
                    g.FillRectangle(wall, W - 28, 0, 28, H);
                }
                DrawFloorTiles(g, t);
            }
            DrawObstacles(g);
            DrawChests(g);
            DrawMeanings(g);
            DrawDrops(g);
            DrawProjectiles(g);
            DrawEnemyProjectiles(g);
            DrawMonsters(g);
            DrawPlayer(g);
            DrawHud(g, t);
            DrawFloating(g);
        }

        bool DrawThemeBackground(Graphics g)
        {
            int themeIndex = (room - 1 + themes.Count) % themes.Count;
            if (themeBackgrounds == null || themeIndex < 0 || themeIndex >= themeBackgrounds.Length) return false;
            Image bg = themeBackgrounds[themeIndex];
            if (bg == null) return false;
            g.DrawImage(bg, 0, 0, W, H);
            return true;
        }

        void DrawFloorTiles(Graphics g, Theme t)
        {
            if (tilesSheet != null)
            {
                int themeIndex = (room - 1 + themes.Count) % themes.Count;
                Rectangle floorSrc = AtlasCell(tilesSheet, 4, 4, themeIndex);
                Rectangle wallSrc = AtlasCell(tilesSheet, 4, 4, 8 + themeIndex);
                for (int x = 28; x < W - 28; x += 128)
                {
                    for (int y = 58; y < H - 30; y += 128)
                    {
                        g.DrawImage(tilesSheet, new Rectangle(x, y, 128, 128), floorSrc, GraphicsUnit.Pixel);
                    }
                }
                for (int x = 0; x < W; x += 128)
                {
                    g.DrawImage(tilesSheet, new Rectangle(x, 0, 128, 58), wallSrc, GraphicsUnit.Pixel);
                    g.DrawImage(tilesSheet, new Rectangle(x, H - 30, 128, 30), wallSrc, GraphicsUnit.Pixel);
                }
                for (int y = 0; y < H; y += 128)
                {
                    g.DrawImage(tilesSheet, new Rectangle(0, y, 28, 128), wallSrc, GraphicsUnit.Pixel);
                    g.DrawImage(tilesSheet, new Rectangle(W - 28, y, 28, 128), wallSrc, GraphicsUnit.Pixel);
                }
            }

            using (Pen p = new Pen(Color.FromArgb(34, Color.White), 1))
            {
                for (int x = 28; x < W; x += 64) g.DrawLine(p, x, 58, x, H - 30);
                for (int y = 58; y < H; y += 64) g.DrawLine(p, 28, y, W - 28, y);
            }
            using (SolidBrush b = new SolidBrush(Color.FromArgb(28, t.Accent)))
            {
                for (int i = 0; i < 7; i++)
                {
                    int x = 100 + ((room * 83 + i * 157) % (W - 220));
                    int y = 100 + ((room * 61 + i * 109) % (H - 210));
                    g.FillEllipse(b, x, y, 28, 10);
                }
            }
        }

        void DrawObstacles(Graphics g)
        {
            foreach (Obstacle obstacle in obstacles)
            {
                RectangleF r = ObstacleVisualSlot(obstacle);
                RectangleF visual = obstaclesSheet != null ? ObstacleVisualBounds(obstacle) : r;
                using (SolidBrush shadow = new SolidBrush(Color.FromArgb(70, 0, 0, 0)))
                {
                    g.FillEllipse(shadow, visual.Left + 5, visual.Bottom - 7, Math.Max(8, visual.Width - 10), 14);
                }

                if (obstaclesSheet != null && obstacleSpriteVisible != null && obstacleSpriteVisible[obstacle.SpriteIndex])
                {
                    DrawAtlasSourceKeepAspect(g, obstaclesSheet, obstacleSpriteSources[obstacle.SpriteIndex], r);
                    continue;
                }

                if (obstacle.Kind == "树木")
                {
                    using (SolidBrush trunk = new SolidBrush(Color.FromArgb(98, 67, 43)))
                    using (SolidBrush leaf = new SolidBrush(obstacle.Fill))
                    using (Pen pen = new Pen(obstacle.Stroke, 2))
                    {
                        g.FillRectangle(trunk, r.Left + r.Width * 0.42f, r.Top + r.Height * 0.46f, r.Width * 0.16f, r.Height * 0.42f);
                        g.FillEllipse(leaf, r.Left, r.Top, r.Width, r.Height * 0.75f);
                        g.DrawEllipse(pen, r.Left, r.Top, r.Width, r.Height * 0.75f);
                    }
                }
                else if (obstacle.Kind == "花草")
                {
                    using (SolidBrush grass = new SolidBrush(obstacle.Fill))
                    using (Pen pen = new Pen(obstacle.Stroke, 2))
                    using (SolidBrush flower = new SolidBrush(Color.FromArgb(230, 134, 160)))
                    {
                        g.FillEllipse(grass, r);
                        g.DrawEllipse(pen, r);
                        g.FillEllipse(flower, r.Left + r.Width * 0.55f, r.Top + r.Height * 0.24f, 9, 9);
                        g.FillEllipse(flower, r.Left + r.Width * 0.28f, r.Top + r.Height * 0.46f, 7, 7);
                    }
                }
                else
                {
                    using (GraphicsPath path = RoundedRect(Rectangle.Round(r), 6))
                    using (SolidBrush fill = new SolidBrush(obstacle.Fill))
                    using (Pen pen = new Pen(obstacle.Stroke, 3))
                    {
                        g.FillPath(fill, path);
                        g.DrawPath(pen, path);
                    }

                    if (obstacle.Kind == "办公桌" || obstacle.Kind == "实验桌")
                    {
                        using (Pen line = new Pen(Color.FromArgb(80, Color.White), 2))
                        {
                            g.DrawLine(line, r.Left + 12, r.Top + r.Height / 2, r.Right - 12, r.Top + r.Height / 2);
                            g.DrawLine(line, r.Left + r.Width / 3, r.Top + 8, r.Left + r.Width / 3, r.Bottom - 8);
                        }
                    }
                    else if (obstacle.Kind == "书架")
                    {
                        using (Pen shelf = new Pen(Color.FromArgb(90, 255, 238, 190), 2))
                        {
                            for (float y = r.Top + 22; y < r.Bottom - 10; y += 28) g.DrawLine(shelf, r.Left + 8, y, r.Right - 8, y);
                        }
                    }
                    else if (obstacle.Kind == "写字楼")
                    {
                        using (SolidBrush window = new SolidBrush(Color.FromArgb(160, 224, 213, 150)))
                        {
                            for (float x = r.Left + 12; x < r.Right - 12; x += 22)
                            {
                                for (float y = r.Top + 12; y < r.Bottom - 12; y += 24)
                                {
                                    g.FillRectangle(window, x, y, 8, 8);
                                }
                            }
                        }
                    }
                    else if (obstacle.Kind == "汽车")
                    {
                        using (SolidBrush wheel = new SolidBrush(Color.FromArgb(30, 35, 40)))
                        using (SolidBrush glass = new SolidBrush(Color.FromArgb(150, 192, 231, 245)))
                        {
                            g.FillRectangle(glass, r.Left + r.Width * 0.32f, r.Top + 8, r.Width * 0.34f, r.Height * 0.32f);
                            g.FillEllipse(wheel, r.Left + 14, r.Bottom - 12, 16, 16);
                            g.FillEllipse(wheel, r.Right - 30, r.Bottom - 12, 16, 16);
                        }
                    }
                }
            }
        }

        void DrawPlayer(Graphics g)
        {
            Vec2 aim = GetAimDirection();
            using (SolidBrush shadow = new SolidBrush(Color.FromArgb(80, 0, 0, 0)))
            {
                float pulse = 1f + (float)Math.Sin(walkAnimTime * 18) * 0.06f;
                g.FillEllipse(shadow, player.Pos.X - 24 * pulse, player.Pos.Y + 14, 48 * pulse, 13);
            }

            if (heroGunActionsSheet != null)
            {
                int frame = HeroActionFrameIndex();
                DrawAtlasCentered(g, heroGunActionsSheet, 8, 4, playerFacing * 8 + frame, player.Pos + new Vec2(0, -14), 90, 90);
                DrawPlayerShield(g);
                return;
            }

            if (heroWalkSheet != null)
            {
                int frame = HeroFrameIndex();
                DrawAtlasCentered(g, heroWalkSheet, 6, 4, playerFacing * 6 + frame, player.Pos + new Vec2(0, -16), 88, 88);
                DrawPlayerShield(g);
                return;                
            }

            if (heroDirectionsSheet != null)
            {
                DrawAtlasCentered(g, heroDirectionsSheet, 4, 1, playerFacing, player.Pos + new Vec2(0, -14), 84, 84);
                DrawPlayerShield(g);
                return;
            }

            if (charactersSheet != null)
            {
                DrawAtlasCentered(g, charactersSheet, 4, 2, 0, player.Pos + new Vec2(0, -14), 84, 84);
                DrawPlayerShield(g);
                return;
            }

            Color body = player.Invulnerable > 0 ? Color.FromArgb(255, 238, 161) : Color.FromArgb(96, 197, 255);
            using (SolidBrush b = new SolidBrush(body))
            using (Pen pen = new Pen(Color.FromArgb(18, 34, 45), 3))
            {
                g.FillEllipse(b, player.Pos.X - 18, player.Pos.Y - 18, 36, 36);
                g.DrawEllipse(pen, player.Pos.X - 18, player.Pos.Y - 18, 36, 36);
            }
            using (Pen aimPen = new Pen(Color.FromArgb(220, 255, 255, 255), 3))
            {
                g.DrawLine(aimPen, player.Pos.ToPointF(), (player.Pos + aim * 45).ToPointF());
            }
            DrawPlayerShield(g);
        }

        int HeroFrameIndex()
        {
            if (dashAnimTime > 0) return 5;
            if (walkAnimTime <= 0.001f) return 0;
            return 1 + ((int)(walkAnimTime * 10f) % 4);
        }

        int HeroActionFrameIndex()
        {
            if (fireAnimTime > 0) return 6;
            if (dashAnimTime > 0) return 5;
            if (player.Invulnerable > 0) return 7;
            if (walkAnimTime <= 0.001f) return 0;
            return 1 + ((int)(walkAnimTime * 10f) % 4);
        }

        void DrawPlayerWeapon(Graphics g, Vec2 aim)
        {
            if (weaponAmmoSheet == null) return;
            float angle = (float)(Math.Atan2(aim.Y, aim.X) * 180.0 / Math.PI);
            float recoil = fireAnimTime > 0 ? 6f * (fireAnimTime / 0.16f) : 0f;
            Vec2 weaponCenter = player.Pos + aim * (27 - recoil) + new Vec2(0, -10);
            DrawRotatedAtlasCentered(g, weaponAmmoSheet, 4, 1, 0, weaponCenter, 46, 30, angle);
            if (fireAnimTime > 0)
            {
                Vec2 muzzle = GetMuzzlePosition(aim);
                float flashSize = 30 + 20 * (fireAnimTime / 0.16f);
                DrawRotatedAtlasCentered(g, weaponAmmoSheet, 4, 1, 1, muzzle, flashSize, flashSize, angle);
            }
        }

        void DrawPlayerShield(Graphics g)
        {
            if (player.ShieldTime > 0)
            {
                using (Pen shield = new Pen(Color.FromArgb(140, 128, 221, 255), 4))
                {
                    g.DrawEllipse(shield, player.Pos.X - 27, player.Pos.Y - 27, 54, 54);
                }
            }
        }

        void DrawMonsters(Graphics g)
        {
            foreach (Monster m in monsters)
            {
                Color c = Color.FromArgb(214, 83, 92);
                if (m.Kind == MonsterKind.Chaser) c = Color.FromArgb(232, 117, 79);
                if (m.Kind == MonsterKind.Dasher) c = Color.FromArgb(236, 185, 73);
                if (m.Kind == MonsterKind.Shield) c = Color.FromArgb(105, 142, 220);
                if (m.Kind == MonsterKind.Ghost) c = Color.FromArgb(174, 111, 214);
                if (m.RageTimer > 0) c = Color.FromArgb(255, 72, 72);

                using (SolidBrush shadow = new SolidBrush(Color.FromArgb(90, 0, 0, 0)))
                {
                    g.FillEllipse(shadow, m.Pos.X - m.Radius, m.Pos.Y + m.Radius - 8, m.Radius * 2, 12);
                }

                if (charactersSheet != null)
                {
                    int sprite = MonsterSpriteIndex(m);
                    float spriteSize = m.Radius * 2.6f;
                    DrawAtlasCentered(g, charactersSheet, 4, 2, sprite, m.Pos + new Vec2(0, -4), spriteSize * 1.22f, spriteSize, m.FacingRight);
                }
                else
                {
                    using (SolidBrush b = new SolidBrush(c))
                    using (Pen pen = new Pen(Color.FromArgb(35, 22, 26), 3))
                    {
                        g.FillEllipse(b, m.Pos.X - m.Radius, m.Pos.Y - m.Radius, m.Radius * 2, m.Radius * 2);
                        g.DrawEllipse(pen, m.Pos.X - m.Radius, m.Pos.Y - m.Radius, m.Radius * 2, m.Radius * 2);
                    }
                }
                if (m.ShieldUp)
                {
                    using (Pen p = new Pen(Color.FromArgb(190, 172, 224, 255), 4))
                    {
                        g.DrawEllipse(p, m.Pos.X - m.Radius - 7, m.Pos.Y - m.Radius - 7, (m.Radius + 7) * 2, (m.Radius + 7) * 2);
                    }
                }
                if (IsEliteMonster(m))
                {
                    using (Pen p = new Pen(Color.FromArgb(150, 255, 188, 112), 2))
                    {
                        g.DrawEllipse(p, m.Pos.X - m.Radius - 12, m.Pos.Y - m.Radius - 12, (m.Radius + 12) * 2, (m.Radius + 12) * 2);
                    }
                }
                SizeF size = g.MeasureString(m.Entry.word, wordFont);
                DrawOutlinedText(g, m.Entry.word, wordFont, m.Pos.X - size.Width / 2, m.Pos.Y - 12, Color.FromArgb(255, 240, 132), Color.FromArgb(18, 18, 24));
                DrawHpBar(g, m.Pos.X - 28, m.Pos.Y + m.Radius + 9, 56, 5, m.Hp / m.MaxHp, Color.FromArgb(255, 222, 118));
            }
        }

        void DrawOutlinedText(Graphics g, string text, Font font, float x, float y, Color fill, Color outline)
        {
            using (SolidBrush outlineBrush = new SolidBrush(outline))
            using (SolidBrush fillBrush = new SolidBrush(fill))
            {
                g.DrawString(text, font, outlineBrush, x - 1, y);
                g.DrawString(text, font, outlineBrush, x + 1, y);
                g.DrawString(text, font, outlineBrush, x, y - 1);
                g.DrawString(text, font, outlineBrush, x, y + 1);
                g.DrawString(text, font, fillBrush, x, y);
            }
        }

        int MonsterSpriteIndex(Monster m)
        {
            if (IsEliteMonster(m)) return 6;
            if (m.Kind == MonsterKind.Chaser) return 2;
            if (m.Kind == MonsterKind.Dasher) return 3;
            if (m.Kind == MonsterKind.Shield) return 4;
            if (m.Kind == MonsterKind.Ghost) return 5;
            return 1;
        }

        void DrawMeanings(Graphics g)
        {
            foreach (MeaningToken token in meanings)
            {
                SizeF size = g.MeasureString(token.Meaning, chineseFont);
                RectangleF r = MeaningTokenBounds(token.Meaning, token.Pos);
                Color fill = Color.FromArgb(224, 229, 170, 82);
                if (token.GlowTimer > 0 && ((int)(roomTime * 5) % 2 == 0)) fill = Color.FromArgb(240, 158, 244, 145);
                using (GraphicsPath path = RoundedRect(Rectangle.Round(r), 7))
                using (SolidBrush b = new SolidBrush(fill))
                using (Pen pen = new Pen(Color.FromArgb(80, 40, 24), 2))
                {
                    g.FillPath(b, path);
                    g.DrawPath(pen, path);
                }
                using (SolidBrush text = new SolidBrush(Color.FromArgb(42, 35, 23)))
                {
                    g.DrawString(token.Meaning, chineseFont, text, token.Pos.X - size.Width / 2, token.Pos.Y - 11);
                }
            }
        }

        void DrawProjectiles(Graphics g)
        {
            foreach (Projectile p in projectiles)
            {
                if (itemsSheet != null)
                {
                    DrawAtlasCentered(g, itemsSheet, 4, 4, p.Universal ? 2 : 1, p.Pos, 34, 34);
                    using (SolidBrush text = new SolidBrush(Color.White))
                    {
                        g.DrawString(p.Universal ? "回声" : p.Meaning, smallFont, text, p.Pos.X + 15, p.Pos.Y - 10);
                    }
                    continue;
                }
                Color fill = p.Universal ? Color.FromArgb(165, 226, 255) : Color.FromArgb(246, 241, 174);
                using (SolidBrush b = new SolidBrush(fill))
                using (Pen pen = new Pen(Color.FromArgb(80, 66, 20), 2))
                {
                    g.FillEllipse(b, p.Pos.X - 9, p.Pos.Y - 9, 18, 18);
                    g.DrawEllipse(pen, p.Pos.X - 9, p.Pos.Y - 9, 18, 18);
                }
                using (SolidBrush text = new SolidBrush(Color.White))
                {
                    g.DrawString(p.Universal ? "回声" : p.Meaning, smallFont, text, p.Pos.X + 11, p.Pos.Y - 10);
                }
            }
        }

        void DrawEnemyProjectiles(Graphics g)
        {
            foreach (EnemyProjectile bullet in enemyProjectiles)
            {
                if (itemsSheet != null)
                {
                    DrawAtlasCentered(g, itemsSheet, 4, 4, 3, bullet.Pos, 30, 30);
                    continue;
                }
                using (SolidBrush glow = new SolidBrush(Color.FromArgb(80, 255, 96, 64)))
                using (SolidBrush core = new SolidBrush(Color.FromArgb(255, 118, 78)))
                using (Pen pen = new Pen(Color.FromArgb(92, 32, 24), 2))
                {
                    g.FillEllipse(glow, bullet.Pos.X - 13, bullet.Pos.Y - 13, 26, 26);
                    g.FillEllipse(core, bullet.Pos.X - 7, bullet.Pos.Y - 7, 14, 14);
                    g.DrawEllipse(pen, bullet.Pos.X - 7, bullet.Pos.Y - 7, 14, 14);
                }
            }
        }

        void DrawDrops(Graphics g)
        {
            foreach (Drop d in drops)
            {
                if (itemsSheet != null)
                {
                    DrawAtlasCentered(g, itemsSheet, 4, 4, DropSpriteIndex(d.Kind), d.Pos, 34, 34);
                    continue;
                }
                Color c = Color.FromArgb(142, 230, 128);
                if (d.Kind == DropKind.Coffee) c = Color.FromArgb(202, 143, 85);
                if (d.Kind == DropKind.ShieldPotion) c = Color.FromArgb(104, 197, 244);
                if (d.Kind == DropKind.Ink) c = Color.FromArgb(164, 126, 234);
                if (d.Kind == DropKind.Boots) c = Color.FromArgb(113, 207, 229);
                if (d.Kind == DropKind.Feather) c = Color.FromArgb(237, 236, 205);
                if (d.Kind == DropKind.Gloves) c = Color.FromArgb(235, 177, 91);
                using (SolidBrush b = new SolidBrush(c))
                using (Pen p = new Pen(Color.FromArgb(45, 35, 28), 2))
                {
                    g.FillEllipse(b, d.Pos.X - 12, d.Pos.Y - 12, 24, 24);
                    g.DrawEllipse(p, d.Pos.X - 12, d.Pos.Y - 12, 24, 24);
                }
            }
        }

        int DropSpriteIndex(DropKind kind)
        {
            if (kind == DropKind.Apple) return 6;
            if (kind == DropKind.Coffee) return 7;
            if (kind == DropKind.ShieldPotion) return 8;
            if (kind == DropKind.Ink) return 9;
            if (kind == DropKind.Boots) return 10;
            if (kind == DropKind.Feather) return 11;
            if (kind == DropKind.Gloves) return 12;
            return 15;
        }

        void DrawChests(Graphics g)
        {
            foreach (Chest c in chests)
            {
                if (c.Opened) continue;
                if (itemsSheet != null)
                {
                    DrawAtlasCentered(g, itemsSheet, 4, 4, 4, c.Pos, 58, 50);
                    continue;
                }
                RectangleF r = new RectangleF(c.Pos.X - 22, c.Pos.Y - 18, 44, 36);
                using (SolidBrush b = new SolidBrush(Color.FromArgb(175, 112, 62)))
                using (Pen p = new Pen(Color.FromArgb(54, 35, 23), 3))
                {
                    g.FillRectangle(b, r.X, r.Y, r.Width, r.Height);
                    g.DrawRectangle(p, r.X, r.Y, r.Width, r.Height);
                    g.DrawLine(p, r.X, r.Y + 16, r.Right, r.Y + 16);
                }
                using (SolidBrush gold = new SolidBrush(Color.FromArgb(244, 205, 86)))
                {
                    g.FillRectangle(gold, c.Pos.X - 5, c.Pos.Y - 1, 10, 9);
                }
            }
        }

        void DrawHud(Graphics g, Theme t)
        {
            using (SolidBrush header = new SolidBrush(Color.FromArgb(198, 16, 20, 25)))
            {
                g.FillRectangle(header, 0, 0, W, 58);
            }
            DrawHpBar(g, 24, 18, 180, 16, player.Hp / player.MaxHp, Color.FromArgb(105, 226, 128));
            using (SolidBrush text = new SolidBrush(Color.White))
            {
                g.DrawString("HP " + Math.Max(0, (int)player.Hp) + "/" + (int)player.MaxHp, smallFont, text, 32, 18);
                g.DrawString("房间 " + room + " · " + themes[(room - 1) % themes.Count].Name + " · " + selectedModeName, smallFont, text, 225, 18);
                g.DrawString("连击 " + combo + "  命中率 " + AccuracyText(), smallFont, text, 560, 18);
                g.DrawString("持有：" + (player.HeldMeaning.Length == 0 ? "无" : player.HeldMeaning), chineseFont, text, 760, 15);
                g.DrawString("已见词 " + runWords.Distinct().Count() + "/" + bankWords.Count, smallFont, text, 1080, 18);
            }
            if (message.Length > 0)
            {
                using (SolidBrush b = new SolidBrush(Color.FromArgb(224, 235, 241)))
                {
                    g.DrawString(message, smallFont, b, 34, H - 25);
                }
            }
            DrawCooldown(g);
        }

        void DrawCooldown(Graphics g)
        {
            float x = 1010;
            float y = 15;
            DrawMiniMeter(g, x, y, "闪避", 1f - Clamp01(player.DashTimer / player.DashCooldown), Color.FromArgb(117, 210, 252));
            DrawMiniMeter(g, x + 78, y, "护盾", Clamp01(player.ShieldTime / 10f), Color.FromArgb(142, 195, 255));
        }

        void DrawMiniMeter(Graphics g, float x, float y, string label, float value, Color color)
        {
            using (Pen p = new Pen(Color.FromArgb(90, 255, 255, 255), 1))
            using (SolidBrush b = new SolidBrush(Color.FromArgb(55, 255, 255, 255)))
            using (SolidBrush fill = new SolidBrush(color))
            using (SolidBrush text = new SolidBrush(Color.White))
            {
                g.DrawRectangle(p, x, y, 56, 10);
                g.FillRectangle(b, x, y, 56, 10);
                g.FillRectangle(fill, x, y, 56 * value, 10);
                g.DrawString(label, smallFont, text, x, y + 12);
            }
        }

        string AccuracyText()
        {
            int total = correctHits + wrongHits;
            if (total == 0) return "100%";
            return ((int)(correctHits * 100f / total)).ToString() + "%";
        }

        void DrawHpBar(Graphics g, float x, float y, float w, float h, float value, Color color)
        {
            value = Clamp01(value);
            using (SolidBrush bg = new SolidBrush(Color.FromArgb(90, 0, 0, 0)))
            using (SolidBrush fill = new SolidBrush(color))
            {
                g.FillRectangle(bg, x, y, w, h);
                g.FillRectangle(fill, x, y, w * value, h);
            }
        }

        void DrawFloating(Graphics g)
        {
            foreach (FloatingText ft in floatingTexts)
            {
                int alpha = (int)(255 * Clamp01(ft.Life / 1.35f));
                using (SolidBrush b = new SolidBrush(Color.FromArgb(alpha, ft.Color)))
                {
                    g.DrawString(ft.Text, smallFont, b, ft.Pos.X, ft.Pos.Y);
                }
            }
        }

        void DrawMemoryBook(Graphics g)
        {
            Rectangle panel = new Rectangle(190, 86, 900, 540);
            using (GraphicsPath path = RoundedRect(panel, 8))
            using (SolidBrush b = new SolidBrush(Color.FromArgb(236, 24, 29, 36)))
            using (Pen p = new Pen(Color.FromArgb(120, 212, 224, 232), 1))
            {
                g.FillPath(b, path);
                g.DrawPath(p, path);
            }
            using (SolidBrush text = new SolidBrush(Color.White))
            {
                g.DrawString("记忆书 - 本局出现词汇", titleFont, text, panel.Left + 28, panel.Top + 22);
            }
            int y = panel.Top + 86;
            IEnumerable<WordEntry> items = runWords.Distinct().Take(16);
            foreach (WordEntry w in items)
            {
                Color c = w.correctCount > w.wrongCount ? Color.FromArgb(170, 245, 185) : Color.FromArgb(255, 222, 138);
                using (SolidBrush b = new SolidBrush(c))
                {
                    g.DrawString(w.word.PadRight(16) + "  =  " + w.meaning + "   正确 " + w.correctCount + "  错误 " + w.wrongCount + "  掌握 " + w.mastery, uiFont, b, panel.Left + 36, y);
                }
                y += 28;
            }
        }

        void DrawOverlayPanel(Graphics g, string title, string body)
        {
            Rectangle panel = new Rectangle(W / 2 - 220, H / 2 - 105, 440, 210);
            using (GraphicsPath path = RoundedRect(panel, 8))
            using (SolidBrush b = new SolidBrush(Color.FromArgb(226, 20, 25, 32)))
            using (Pen p = new Pen(Color.FromArgb(120, 220, 230, 240), 1))
            {
                g.FillPath(b, path);
                g.DrawPath(p, path);
            }
            using (SolidBrush b = new SolidBrush(Color.White))
            {
                DrawCentered(g, title, titleFont, b, panel.Top + 42);
                DrawCentered(g, body, uiFont, b, panel.Top + 118);
            }
        }

        Rectangle RewardCardRect(int index)
        {
            int width = 250;
            int height = 218;
            int gap = 28;
            int total = width * 3 + gap * 2;
            int x = W / 2 - total / 2 + index * (width + gap);
            return new Rectangle(x, 245, width, height);
        }

        void DrawRewardChoice(Graphics g)
        {
            using (SolidBrush veil = new SolidBrush(Color.FromArgb(172, 9, 13, 19)))
            {
                g.FillRectangle(veil, ClientRectangle);
            }

            using (SolidBrush title = new SolidBrush(Color.White))
            using (SolidBrush sub = new SolidBrush(Color.FromArgb(216, 226, 235)))
            {
                DrawCentered(g, "房间补给", titleFont, title, 116);
                DrawCentered(g, "选择一张奖励卡，然后开始第 " + room + " 间", uiFont, sub, 166);
                DrawCentered(g, "快捷键 1 / 2 / 3", smallFont, sub, 198);
            }

            for (int i = 0; i < rewardCards.Count; i++)
            {
                DrawRewardCard(g, rewardCards[i], RewardCardRect(i), i + 1);
            }
        }

        void DrawRewardCard(Graphics g, RewardCard card, Rectangle rect, int number)
        {
            Color accent = Color.FromArgb(116, 201, 255);
            if (card.Kind == RewardKind.Survival) accent = Color.FromArgb(126, 229, 151);
            else if (card.Kind == RewardKind.MoveSpeed || card.Kind == RewardKind.Shield) accent = Color.FromArgb(125, 189, 255);
            else accent = Color.FromArgb(255, 211, 105);

            using (GraphicsPath path = RoundedRect(rect, 8))
            using (SolidBrush bg = new SolidBrush(Color.FromArgb(238, 28, 34, 43)))
            using (Pen border = new Pen(Color.FromArgb(210, accent), 2))
            {
                g.FillPath(bg, path);
                g.DrawPath(border, path);
            }

            Rectangle badge = new Rectangle(rect.Left + 18, rect.Top + 18, 42, 34);
            using (GraphicsPath path = RoundedRect(badge, 7))
            using (SolidBrush b = new SolidBrush(Color.FromArgb(210, accent)))
            {
                g.FillPath(b, path);
            }

            using (SolidBrush dark = new SolidBrush(Color.FromArgb(24, 28, 34)))
            using (SolidBrush text = new SolidBrush(Color.White))
            using (SolidBrush muted = new SolidBrush(Color.FromArgb(202, 214, 224)))
            using (SolidBrush accentBrush = new SolidBrush(accent))
            {
                DrawCenteredInRect(g, number.ToString(), chineseFont, dark, badge);
                g.DrawString(card.Category, smallFont, accentBrush, rect.Left + 76, rect.Top + 23);
                g.DrawString(card.Title, titleFont, text, rect.Left + 22, rect.Top + 70);
                g.DrawString(card.Description, chineseFont, muted, new Rectangle(rect.Left + 22, rect.Top + 126, rect.Width - 44, 58));
                DrawCenteredInRect(g, "选择", uiFont, accentBrush, new Rectangle(rect.Left + 22, rect.Bottom - 48, rect.Width - 44, 30));
            }
        }

        void DrawEndScreen(Graphics g, string title)
        {
            using (SolidBrush veil = new SolidBrush(Color.FromArgb(210, 12, 15, 21)))
            {
                g.FillRectangle(veil, ClientRectangle);
            }
            using (SolidBrush b = new SolidBrush(Color.White))
            {
                DrawCentered(g, title, titleFont, b, 54);
            }
            using (SolidBrush b = new SolidBrush(Color.FromArgb(205, 218, 226)))
            {
                DrawCentered(g, message, uiFont, b, 106);
            }
            Rectangle list = new Rectangle(150, 150, 980, 500);
            using (GraphicsPath path = RoundedRect(list, 8))
            using (SolidBrush panel = new SolidBrush(Color.FromArgb(234, 31, 37, 46)))
            {
                g.FillPath(panel, path);
            }
            using (SolidBrush b = new SolidBrush(Color.FromArgb(245, 246, 247)))
            {
                g.DrawString("本局词汇回顾", chineseFont, b, list.Left + 26, list.Top + 20);
            }
            int y = list.Top + 60;
            foreach (WordEntry w in runWords.Distinct().Take(18))
            {
                using (SolidBrush b = new SolidBrush(Color.FromArgb(214, 225, 232)))
                {
                    g.DrawString(w.word, wordFont, b, list.Left + 35, y);
                    g.DrawString(w.meaning, chineseFont, b, list.Left + 250, y - 1);
                    g.DrawString("正确 " + w.correctCount + " / 错误 " + w.wrongCount + " / 死亡复现 " + w.deathCount, smallFont, b, list.Left + 480, y + 2);
                }
                y += 25;
            }
        }

        void DrawCentered(Graphics g, string text, Font font, Brush brush, float y)
        {
            SizeF s = g.MeasureString(text, font);
            g.DrawString(text, font, brush, W / 2 - s.Width / 2, y);
        }

        void DrawCenteredInRect(Graphics g, string text, Font font, Brush brush, Rectangle rect)
        {
            using (StringFormat format = new StringFormat())
            {
                format.Alignment = StringAlignment.Center;
                format.LineAlignment = StringAlignment.Center;
                format.Trimming = StringTrimming.EllipsisCharacter;
                g.DrawString(text, font, brush, rect, format);
            }
        }

        GraphicsPath RoundedRect(Rectangle bounds, int radius)
        {
            int d = radius * 2;
            GraphicsPath path = new GraphicsPath();
            path.AddArc(bounds.X, bounds.Y, d, d, 180, 90);
            path.AddArc(bounds.Right - d, bounds.Y, d, d, 270, 90);
            path.AddArc(bounds.Right - d, bounds.Bottom - d, d, d, 0, 90);
            path.AddArc(bounds.X, bounds.Bottom - d, d, d, 90, 90);
            path.CloseFigure();
            return path;
        }

        float Clamp(float value, float min, float max)
        {
            if (value < min) return min;
            if (value > max) return max;
            return value;
        }

        float Clamp01(float value)
        {
            return Clamp(value, 0, 1);
        }

        List<WordEntry> LoadWords()
        {
            string path = Path.Combine(baseDir, "wordbank.json");
            try
            {
                if (!File.Exists(path))
                {
                    string source = Path.Combine(Directory.GetCurrentDirectory(), "wordbank.json");
                    if (File.Exists(source)) path = source;
                }
                if (File.Exists(path))
                {
                    JavaScriptSerializer serializer = new JavaScriptSerializer();
                    serializer.MaxJsonLength = 1024 * 1024 * 16;
                    return serializer.Deserialize<List<WordEntry>>(File.ReadAllText(path, Encoding.UTF8));
                }
            }
            catch
            {
            }
            return DefaultWords();
        }

        SaveData LoadSave()
        {
            try
            {
                string path = Path.Combine(baseDir, "savegame.json");
                if (File.Exists(path))
                {
                    JavaScriptSerializer serializer = new JavaScriptSerializer();
                    return serializer.Deserialize<SaveData>(File.ReadAllText(path, Encoding.UTF8));
                }
            }
            catch
            {
            }
            SaveData data = new SaveData();
            data.words = new List<WordEntry>();
            return data;
        }

        void MergeSavedStats()
        {
            if (saveData.words == null) saveData.words = new List<WordEntry>();
            Dictionary<string, WordEntry> saved = new Dictionary<string, WordEntry>();
            foreach (WordEntry w in saveData.words)
            {
                if (!saved.ContainsKey(w.word)) saved.Add(w.word, w);
            }
            foreach (WordEntry w in allWords)
            {
                if (saved.ContainsKey(w.word))
                {
                    WordEntry s = saved[w.word];
                    w.seenCount = s.seenCount;
                    w.correctCount = s.correctCount;
                    w.wrongCount = s.wrongCount;
                    w.deathCount = s.deathCount;
                    w.mastery = s.mastery;
                    w.lastSeenRoom = s.lastSeenRoom;
                }
            }
        }

        void SaveContinueState()
        {
            if (saveData == null || player == null) return;
            if (state == GameState.Menu || state == GameState.GameOver || state == GameState.Win) return;

            saveData.hasContinue = true;
            saveData.continueMode = selectedMode;
            saveData.continueModeName = selectedModeName;
            saveData.continueRoom = Math.Max(1, room);
            saveData.continueHp = Math.Max(1, player.Hp);
            saveData.continueSpeed = player.Speed;
            saveData.continueDashCooldown = player.DashCooldown;
            saveData.continueThrowSpeed = player.ThrowSpeed;
            saveData.continuePickupRange = player.PickupRange;
            saveData.continueDefense = player.Defense;
            saveData.continueLuck = player.Luck;
            saveData.continuePiercingInkRooms = piercingInkRooms;
            saveData.continueEchoScrollRooms = echoScrollRooms;
            saveData.continueSpeedBoostRooms = speedBoostRooms;
            saveData.continueThrowBoostRooms = throwBoostRooms;
            saveData.continueDashBoostRooms = dashBoostRooms;
            saveData.continuePickupBoostRooms = pickupBoostRooms;
            saveData.continueTempSpeedBonus = tempSpeedBonus;
            saveData.continueTempThrowBonus = tempThrowBonus;
            saveData.continueTempDashBonus = tempDashBonus;
            saveData.continueTempPickupBonus = tempPickupBonus;
            Save();
        }

        void Save()
        {
            try
            {
                saveData.words = allWords;
                string path = Path.Combine(baseDir, "savegame.json");
                JavaScriptSerializer serializer = new JavaScriptSerializer();
                serializer.MaxJsonLength = 1024 * 1024 * 16;
                File.WriteAllText(path, serializer.Serialize(saveData), Encoding.UTF8);
            }
            catch
            {
            }
        }

        List<WordEntry> DefaultWords()
        {
            List<WordEntry> words = new List<WordEntry>();
            words.Add(MakeWord("increase", "增加", 2, "verb", "academic"));
            words.Add(MakeWord("decrease", "减少", 2, "verb", "academic"));
            words.Add(MakeWord("include", "包含", 2, "verb", "academic"));
            words.Add(MakeWord("improve", "改善", 2, "verb", "daily"));
            words.Add(MakeWord("affect", "影响", 3, "verb", "academic"));
            words.Add(MakeWord("market", "市场", 2, "business", "noun"));
            words.Add(MakeWord("research", "研究", 3, "academic", "noun"));
            words.Add(MakeWord("transport", "运输", 3, "travel", "noun"));
            return words;
        }

        WordEntry MakeWord(string word, string meaning, int difficulty, params string[] tags)
        {
            WordEntry w = new WordEntry();
            w.word = word;
            w.meaning = meaning;
            w.difficulty = difficulty;
            w.frequencyRank = 1000 + difficulty * 600;
            w.tags = tags;
            return w;
        }
    }
}
