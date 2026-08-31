namespace LadderSocial.Infrastructure.Persistence.Seed;

internal static class DemoSeedCatalog
{
    public static readonly IReadOnlyCollection<DemoUserSpec> Users =
        new DemoUserSpec[]
        {
        new("faruk", "faruk@laddersocial.local", "Faruk", "Caluk", "Building better habits one day at a time.", "faruk.png", "Sarajevo", new DateOnly(1998, 4, 12), 96),
        new("ajdin", "ajdin@laddersocial.local", "Ajdin", "Hajdarevic", "Designer, developer and lifelong learner.", "ajdin.png", "Mostar", new DateOnly(1999, 8, 21), 88),
        new("harun", "harun@laddersocial.local", "Harun", "Music", "Focused on fitness, databases and consistent progress.", "harun.png", "Tuzla", new DateOnly(1998, 11, 5), 82),
        new("edhem", "edhem@laddersocial.local", "Edhem", "Kevric", "Planning work, finishing tasks and sharing the journey.", "edhem.png", "Zenica", new DateOnly(2000, 2, 17), 76),
        new("amina", "amina@laddersocial.local", "Amina", "Saric", "Small steps, calm mornings and meaningful work.", "amina.png", "Sarajevo", new DateOnly(1999, 6, 9), 70),
        new("lejla", "lejla@laddersocial.local", "Lejla", "Basic", "Writing, mindfulness and creative routines.", "lejla.png", "Mostar", new DateOnly(2000, 10, 2), 64),
        new("amar", "amar@laddersocial.local", "Amar", "Kovac", "Running, reading and improving every week.", "amar.png", "Banja Luka", new DateOnly(1998, 3, 28), 58),
        new("selma", "selma@laddersocial.local", "Selma", "Alic", "Studying smarter and making time for friends.", "selma.png", "Tuzla", new DateOnly(2001, 1, 14), 52)
        };

    public static readonly IReadOnlyCollection<DemoTaskSpec> Tasks =
        new DemoTaskSpec[]
        {
        new("mobile-presentation", "mobile", "Prepare monthly presentation", "Finish the presentation and review the key metrics.", "work", "none", 0, 10, true, true),
        new("mobile-dentist", "mobile", "Book dentist appointment", "Call the clinic and choose an available appointment.", "self-care", "none", 1, 15, false, false),
        new("mobile-blog", "mobile", "Brainstorm ideas for blog", "Write at least five ideas for the next article.", "creative", "none", 0, 20, false, true),
        new("mobile-mindfulness", "mobile", "Evening mindfulness meditation", "Spend ten quiet minutes without distractions.", "self-care", "daily", null, 20, true, true),
        new("mobile-call-mom", "mobile", "Call mom and catch up", "Make time for a proper conversation.", "social", "daily", null, 18, false, true),
        new("mobile-brush-teeth", "mobile", "Brush teeth", "Keep the morning and evening routine consistent.", "self-care", "daily", null, 8, false, false),
        new("mobile-walk-dog", "mobile", "Walk the dog", "Take a longer route through the neighbourhood.", "self-care", "weekly", -14, 17, true, false),
        new("mobile-hike", "mobile", "Go for a hike", "Spend time outside and complete the marked trail.", "self-care", "weekly", -14, 9, true, true),
        new("mobile-weekly-plan", "mobile", "Plan the coming week", "Review priorities and create a realistic schedule.", "work", "weekly", -14, 19, true, true),
        new("mobile-private-journal", "mobile", "Write a private journal entry", "Reflect on the week without sharing the entry.", "creative", "none", null, 21, false, false),

        new("faruk-report", "faruk", "Finish quarterly report draft", "Complete the first draft before the team review.", "work", "none", 0, 11, false, true),
        new("faruk-stretch", "faruk", "Stretch for 10 minutes", "Complete a short mobility routine.", "self-care", "none", 0, 8, true, true),
        new("faruk-read", "faruk", "Read a chapter before bed", "Read one full chapter and write a short note.", "creative", "none", 0, 22, false, true),
        new("faruk-run", "faruk", "Morning run", "Complete the planned daily run.", "self-care", "daily", null, 7, true, true),
        new("faruk-sync", "faruk", "Team project sync", "Review the sprint goals with the team.", "social", "none", 0, 13, false, true),
        new("faruk-hike", "faruk", "Weekend trail preparation", "Pack the essentials for the next trail.", "self-care", "weekly", -14, 10, true, true),
        new("faruk-meditation", "faruk", "Evening meditation", "Complete the daily breathing exercise.", "self-care", "daily", null, 21, false, true),

        new("ajdin-design", "ajdin", "Review mobile design", "Polish the dashboard and task-flow screens.", "creative", "none", 0, 10, true, true),
        new("ajdin-grocery", "ajdin", "Grocery shopping", "Buy the planned groceries for the week.", "self-care", "none", 0, 16, false, true),
        new("ajdin-code", "ajdin", "Complete coding practice", "Finish the planned algorithms exercise.", "work", "none", 0, 14, true, true),
        new("ajdin-read", "ajdin", "Read for 20 minutes", "Keep the daily reading habit active.", "creative", "daily", null, 20, false, true),
        new("ajdin-friends", "ajdin", "Go out with friends", "Plan a relaxed evening with the group.", "social", "none", 0, 19, true, true),
        new("ajdin-plan", "ajdin", "Plan next design sprint", "Prepare next week's design tasks.", "work", "weekly", -14, 18, false, true),

        new("amina-email", "amina", "Send client follow-up", "Send the agreed summary and next steps.", "work", "none", 0, 9, false, true),
        new("amina-yoga", "amina", "Morning yoga", "Complete the short daily yoga flow.", "self-care", "daily", null, 7, true, true),
        new("amina-language", "amina", "Practice a new language", "Review vocabulary for twenty minutes.", "creative", "daily", null, 17, false, true),
        new("amina-family", "amina", "Call family", "Check in and make plans for the weekend.", "social", "weekly", -14, 20, false, true),

        new("harun-database", "harun", "Study database indexing", "Review index design and query plans.", "work", "none", 0, 12, true, true),
        new("harun-gym", "harun", "Gym session", "Complete the strength workout.", "self-care", "daily", null, 18, true, true),
        new("harun-plan", "harun", "Create project plan", "Break the project into clear milestones.", "work", "weekly", -14, 16, false, true),

        new("edhem-presentation", "edhem", "Prepare client presentation", "Build a concise presentation for the next meeting.", "work", "none", 0, 15, true, true),
        new("edhem-walk", "edhem", "Evening walk", "Walk for at least thirty minutes.", "self-care", "daily", null, 19, false, true),
        new("edhem-budget", "edhem", "Review monthly budget", "Categorize expenses and update the plan.", "work", "monthly", -60, 18, false, false),

        new("lejla-article", "lejla", "Write article outline", "Prepare the outline for the next article.", "creative", "none", 0, 17, false, true),
        new("lejla-meditation", "lejla", "Mindfulness practice", "Complete the daily mindfulness session.", "self-care", "daily", null, 8, true, true),
        new("amar-run", "amar", "Run five kilometres", "Complete the planned outdoor run.", "self-care", "weekly", -14, 7, true, true),
        new("amar-read", "amar", "Read technical article", "Read and summarize one technical article.", "work", "none", 1, 20, false, false),
        new("selma-study", "selma", "Study for the exam", "Complete two focused study sessions.", "work", "daily", null, 13, false, true),
        new("selma-friends", "selma", "Meet friends", "Take a break and spend time with friends.", "social", "weekly", -14, 19, true, true)
        };

    public static readonly IReadOnlyCollection<(string Left, string Right)> Friendships =
        new (string Left, string Right)[]
        {
        ("mobile", "faruk"),
        ("mobile", "ajdin"),
        ("mobile", "amina"),
        ("faruk", "harun"),
        ("faruk", "edhem"),
        ("ajdin", "harun"),
        ("ajdin", "selma"),
        ("amina", "lejla"),
        ("harun", "selma")
        };

    public static readonly IReadOnlyCollection<DemoFriendRequestSpec> FriendRequests =
        new DemoFriendRequestSpec[]
        {
        new("edhem", "mobile"),
        new("amar", "mobile"),
        new("mobile", "lejla")
        };

    public static readonly IReadOnlyCollection<DemoCompletionSpec> Completions =
        new DemoCompletionSpec[]
        {
        new("mobile-presentation", 0, 10, "Presentation draft reviewed and ready.", "The monthly presentation is ready.", "project.png", true, true),
        new("mobile-mindfulness", 0, 20, "Ten calm minutes completed.", "Ending the day with a clear mind.", "mindfulness.png", false, true),
        new("mobile-call-mom", 0, 18, "Great conversation.", "Made time for family today.", null, false, true),
        new("mobile-mindfulness", -1, 20, "Stayed consistent.", "Another mindful evening.", "mindfulness.png", false, true),
        new("mobile-mindfulness", -2, 20, "Breathing exercise completed.", null, "mindfulness.png", false, true),
        new("mobile-mindfulness", -3, 20, "Quiet session completed.", null, "mindfulness.png", false, true),
        new("mobile-mindfulness", -4, 20, "Five-day streak started here.", null, "mindfulness.png", false, true),
        new("mobile-hike", -7, 9, "Completed the full trail.", "Fresh air and a productive morning.", "hike.png", true, true),
        new("mobile-weekly-plan", -7, 19, "Priorities scheduled.", "The coming week is organized.", "planning.png", true, true),

        new("faruk-report", 0, 11, "Draft submitted.", "Quarterly report draft finished.", null, false, true),
        new("faruk-stretch", 0, 8, "Mobility routine completed.", "Ten minutes of stretching before work.", "workout.png", true, true),
        new("faruk-read", 0, 22, "Chapter completed.", "Finished tonight's reading.", null, false, true),
        new("faruk-run", 0, 7, "Five kilometres completed.", "Morning run done before breakfast.", "hike.png", true, true),
        new("faruk-sync", 0, 13, "Sprint priorities agreed.", "Good project sync with the team.", null, false, true),
        new("faruk-run", -1, 7, "Daily run completed.", null, "hike.png", false, true),
        new("faruk-run", -2, 7, "Daily run completed.", null, "hike.png", false, true),
        new("faruk-run", -3, 7, "Daily run completed.", null, "hike.png", false, true),
        new("faruk-run", -4, 7, "Daily run completed.", null, "hike.png", false, true),
        new("faruk-run", -5, 7, "Daily run completed.", null, "hike.png", false, true),
        new("faruk-run", -6, 7, "Daily run completed.", null, "hike.png", false, true),

        new("ajdin-design", 0, 10, "Design review completed.", "The new mobile flow is ready for feedback.", "project.png", true, true),
        new("ajdin-grocery", 0, 16, "Shopping list completed.", "Groceries done for the week.", null, false, true),
        new("ajdin-code", 0, 14, "Practice session completed.", "Finished today's coding challenge.", "focus.png", true, true),
        new("ajdin-read", 0, 20, "Reading session completed.", "Twenty minutes of focused reading.", null, false, true),
        new("ajdin-read", -1, 20, "Reading session completed.", null, null, false, true),
        new("ajdin-read", -2, 20, "Reading session completed.", null, null, false, true),
        new("ajdin-read", -3, 20, "Reading session completed.", null, null, false, true),

        new("amina-email", 0, 9, "Follow-up sent.", "Client follow-up completed early.", null, false, true),
        new("amina-yoga", 0, 7, "Yoga flow completed.", "A calm start to the day.", "mindfulness.png", true, true),
        new("amina-yoga", -1, 7, "Yoga flow completed.", null, "mindfulness.png", false, true),
        new("amina-yoga", -2, 7, "Yoga flow completed.", null, "mindfulness.png", false, true),

        new("harun-database", 0, 12, "Indexing notes completed.", "Finished the database indexing lesson.", "reading.png", true, true),
        new("harun-gym", 0, 18, "Workout completed.", "Strength session finished.", "workout.png", false, true),
        new("harun-plan", 0, 16, "Project milestones created.", "Project plan ready for the team.", null, false, true),
        new("edhem-presentation", 0, 15, "Presentation completed.", "Client presentation ready.", "project.png", false, false),
        new("lejla-article", 0, 17, "Outline completed.", "The article structure is ready.", null, false, true),
        new("amar-run", 0, 7, "Run completed.", "Five kilometres before work.", "hike.png", false, true),
        new("selma-study", 0, 13, "Two sessions completed.", "Productive study day.", null, false, true)
        };

    public static readonly IReadOnlyCollection<DemoConversationSpec> Conversations =
        new DemoConversationSpec[]
        {
        new("mobile-faruk", "mobile", "faruk",
        new DemoMessageSpec[]
        {
            new("faruk", -180, "Morning! Are you working on the presentation today?", false),
            new("mobile", -170, "Yes, I want to finish the draft before lunch.", false),
            new("faruk", -120, "Nice. I just finished my report draft.", false),
            new("mobile", -95, "That is good motivation. I am almost done too.", false),
            new("faruk", -35, null, true),
            new("faruk", -12, "The proof image is from this morning's run.", false)
        }),
        new("mobile-ajdin", "mobile", "ajdin",
        new DemoMessageSpec[]
        {
            new("mobile", -240, "How is the design review going?", false),
            new("ajdin", -225, "Almost finished. I changed the mobile flow.", false),
            new("mobile", -210, "Send it when it is ready.", false),
            new("ajdin", -55, "Done. The latest version is much cleaner.", false)
        }),
        new("mobile-amina", "mobile", "amina",
        new DemoMessageSpec[]
        {
            new("amina", -300, "Do you want to join the mindfulness challenge this week?", false),
            new("mobile", -285, "Yes, I already completed today's session.", false),
            new("amina", -65, "Great, I finished yoga this morning too.", false)
        })
        };
}

internal sealed record DemoUserSpec(
    string Key,
    string Email,
    string FirstName,
    string LastName,
    string Bio,
    string AvatarAsset,
    string CityName,
    DateOnly DateOfBirth,
    int CreatedDaysAgo);

internal sealed record DemoTaskSpec(
    string Key,
    string OwnerKey,
    string Title,
    string Description,
    string CategoryCode,
    string RecurrenceCode,
    int? DueDayOffset,
    int DueHour,
    bool RequiresProof,
    bool ShareWithFriends);

internal sealed record DemoFriendRequestSpec(string SenderKey, string ReceiverKey);

internal sealed record DemoCompletionSpec(
    string TaskKey,
    int DayOffset,
    int Hour,
    string? Note,
    string? Caption,
    string? ProofAsset,
    bool Highlight,
    bool PostVisible);

internal sealed record DemoConversationSpec(
    string Key,
    string FirstUserKey,
    string SecondUserKey,
    IReadOnlyCollection<DemoMessageSpec> Messages);

internal sealed record DemoMessageSpec(
    string SenderKey,
    int MinuteOffset,
    string? Content,
    bool HasImage);
