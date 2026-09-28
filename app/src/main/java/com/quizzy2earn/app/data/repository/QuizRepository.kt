package com.quizzy2earn.app.data.repository

import com.quizzy2earn.app.data.model.QuizCategory
import com.quizzy2earn.app.data.model.QuizQuestion

object QuizRepository {

    val categories = listOf(
        QuizCategory(
            id = "general",
            name = "General Knowledge",
            iconName = "School",
            description = "Test your trivia wits on global facts and curiosity!",
            totalLevels = 10,
            baseRewardCoins = 50
        ),
        QuizCategory(
            id = "science",
            name = "Science & Tech",
            iconName = "Science",
            description = "Explore discoveries, computing, and the cosmos!",
            totalLevels = 10,
            baseRewardCoins = 60
        ),
        QuizCategory(
            id = "history",
            name = "History & Geo",
            iconName = "Public",
            description = "Travel through ancient empires, capitals, and landmarks.",
            totalLevels = 10,
            baseRewardCoins = 55
        ),
        QuizCategory(
            id = "entertainment",
            name = "Pop Culture",
            iconName = "Movie",
            description = "Blockbusters, hit songs, anime, and celebrity lore.",
            totalLevels = 10,
            baseRewardCoins = 45
        ),
        QuizCategory(
            id = "sports",
            name = "Sports & Games",
            iconName = "SportsSoccer",
            description = "Champions, world records, athletics, and esports.",
            totalLevels = 10,
            baseRewardCoins = 50
        )
    )

    private val questionBank = mapOf(
        "general" to listOf(
            QuizQuestion("g1", "What is the capital of Australia?", listOf("Sydney", "Melbourne", "Canberra", "Brisbane"), 2, "Canberra was chosen as the compromise capital in 1908."),
            QuizQuestion("g2", "Which element has the chemical symbol 'Au'?", listOf("Silver", "Gold", "Copper", "Platinum"), 1, "Au comes from the Latin word 'Aurum'."),
            QuizQuestion("g3", "How many continents are there on Earth?", listOf("5", "6", "7", "8"), 2, "The 7 continents are Asia, Africa, North America, South America, Antarctica, Europe, and Australia."),
            QuizQuestion("g4", "Which ocean is the largest by surface area?", listOf("Atlantic", "Indian", "Arctic", "Pacific"), 3, "The Pacific Ocean covers more than 30% of Earth's surface."),
            QuizQuestion("g5", "In what year did the Titanic sink?", listOf("1905", "1912", "1918", "1923"), 1, "The RMS Titanic sank on April 15, 1912."),
            QuizQuestion("g6", "What is the hardest natural mineral known?", listOf("Quartz", "Topaz", "Diamond", "Corundum"), 2, "Diamond rates 10 on the Mohs scale."),
            QuizQuestion("g7", "Which language has the most native speakers globally?", listOf("English", "Spanish", "Mandarin Chinese", "Hindi"), 2, "Mandarin has over 900 million native speakers."),
            QuizQuestion("g8", "Which country is home to the kangaroo?", listOf("South Africa", "Australia", "New Zealand", "Madagascar"), 1, "Kangaroos are indigenous to Australia."),
            QuizQuestion("g9", "How many degrees are in a full circle?", listOf("180", "270", "360", "400"), 2, "A full rotation is 360 degrees."),
            QuizQuestion("g10", "What is the primary currency of Japan?", listOf("Yuan", "Won", "Yen", "Baht"), 2, "The Japanese currency is the Yen (¥).")
        ),
        "science" to listOf(
            QuizQuestion("s1", "What is the power house of the biological cell?", listOf("Nucleus", "Ribosome", "Mitochondria", "Cytoplasm"), 2, "Mitochondria generate most of the cell's ATP chemical energy."),
            QuizQuestion("s2", "What is the speed of light in vacuum (approx)?", listOf("150,000 km/s", "300,000 km/s", "500,000 km/s", "1,000,000 km/s"), 1, "Light travels at roughly 299,792 km/s."),
            QuizQuestion("s3", "Which planet in our solar system has the most moons?", listOf("Mars", "Jupiter", "Saturn", "Neptune"), 2, "Saturn has over 140 confirmed natural satellites."),
            QuizQuestion("s4", "What does DNA stand for?", listOf("Deoxyribonucleic Acid", "Diribonucleic Atom", "Dextronitrate Acid", "Deoxynitro Acid"), 0, "DNA contains genetic blueprints."),
            QuizQuestion("s5", "Which gas is most abundant in Earth's atmosphere?", listOf("Oxygen", "Nitrogen", "Carbon Dioxide", "Argon"), 1, "Nitrogen accounts for about 78% of Earth's atmosphere."),
            QuizQuestion("s6", "What subatomic particle carries a negative electric charge?", listOf("Proton", "Neutron", "Electron", "Positron"), 2, "Electrons carry an elementary charge of -1."),
            QuizQuestion("s7", "Who developed the theory of General Relativity?", listOf("Isaac Newton", "Albert Einstein", "Niels Bohr", "Galileo Galilei"), 1, "Einstein published General Relativity in 1915."),
            QuizQuestion("s8", "What type of wave does not require a physical medium?", listOf("Sound wave", "Electromagnetic wave", "Water wave", "Seismic wave"), 1, "Light and radio waves travel through empty vacuum."),
            QuizQuestion("s9", "Which organ in the human body filters blood?", listOf("Liver", "Kidneys", "Lungs", "Spleen"), 1, "Kidneys filter waste to form urine."),
            QuizQuestion("s10", "What is the binary representation of decimal 10?", listOf("1001", "1010", "1100", "1110"), 1, "8 + 2 = 10, which corresponds to 1010 in binary.")
        ),
        "history" to listOf(
            QuizQuestion("h1", "Who was the first President of the United States?", listOf("Thomas Jefferson", "Alexander Hamilton", "George Washington", "John Adams"), 2, "Washington served from 1789 to 1797."),
            QuizQuestion("h2", "In which modern country was the ancient city of Babylon located?", listOf("Egypt", "Iraq", "Syria", "Greece"), 1, "Babylon was located on the Euphrates river in modern Iraq."),
            QuizQuestion("h3", "Which civilization built the Machu Picchu citadel?", listOf("Aztec", "Maya", "Inca", "Olmec"), 2, "Machu Picchu was built in the 15th century by the Incas in Peru."),
            QuizQuestion("h4", "What is the longest river in the world?", listOf("Amazon", "Nile", "Yangtze", "Mississippi"), 1, "The Nile stretches approximately 6,650 km."),
            QuizQuestion("h5", "Which European city is known as the 'City of Canals'?", listOf("Amsterdam", "Venice", "Bruges", "Hamburg"), 1, "Venice is famous for its Grand Canal and gondolas."),
            QuizQuestion("h6", "Who painted the Mona Lisa?", listOf("Michelangelo", "Raphael", "Leonardo da Vinci", "Donatello"), 2, "Leonardo painted it during the Italian Renaissance."),
            QuizQuestion("h7", "What wall fell in 1989, symbolizing the end of the Cold War?", listOf("Great Wall", "Berlin Wall", "Hadrian's Wall", "Western Wall"), 1, "The Berlin Wall fell on November 9, 1989."),
            QuizQuestion("h8", "Which country has the most natural pyramids in the world?", listOf("Egypt", "Sudan", "Mexico", "Peru"), 1, "Sudan has over 200 Nubian pyramids."),
            QuizQuestion("h9", "What was the ancient trade route connecting China to the Mediterranean?", listOf("Amber Road", "Spice Route", "Silk Road", "Tea Horse Trail"), 2, "The Silk Road facilitated commerce and cultural exchange."),
            QuizQuestion("h10", "Mount Everest is located on the border between Nepal and which territory?", listOf("India", "Bhutan", "China (Tibet)", "Myanmar"), 2, "The summit sits on the border of Nepal and China.")
        ),
        "entertainment" to listOf(
            QuizQuestion("e1", "Which movie won the Best Picture Oscar in 1997?", listOf("Titanic", "Good Will Hunting", "L.A. Confidential", "Saving Private Ryan"), 0, "Titanic tied records with 11 Academy Awards."),
            QuizQuestion("e2", "Who plays Iron Man in the Marvel Cinematic Universe?", listOf("Chris Evans", "Robert Downey Jr.", "Chris Hemsworth", "Mark Ruffalo"), 1, "RDJ portrayed Tony Stark from 2008 to 2019."),
            QuizQuestion("e3", "Which pop icon is known as the 'Queen of Pop'?", listOf("Britney Spears", "Madonna", "Beyonce", "Lady Gaga"), 1, "Madonna has been celebrated as the Queen of Pop for decades."),
            QuizQuestion("e4", "In 'The Matrix', which color pill does Neo choose?", listOf("Red", "Blue", "Green", "Yellow"), 0, "Neo takes the red pill to see how deep the rabbit hole goes."),
            QuizQuestion("e5", "What is the fictional kingdom in Disney's 'Frozen'?", listOf("Corona", "Arendelle", "DunBroch", "Genovia"), 1, "Arendelle is ruled by Elsa and Anna."),
            QuizQuestion("e6", "Who created the animated series 'The Simpsons'?", listOf("Seth MacFarlane", "Matt Groening", "Mike Judge", "Trey Parker"), 1, "Matt Groening created the iconic animated family."),
            QuizQuestion("e7", "Which band released the iconic 1969 album 'Abbey Road'?", listOf("The Rolling Stones", "The Who", "The Beatles", "Pink Floyd"), 2, "Abbey Road was the final recorded Beatles album."),
            QuizQuestion("e8", "What is the name of Mario's twin brother in Nintendo games?", listOf("Wario", "Luigi", "Toad", "Bowser"), 1, "Luigi wears green overalls and assists Mario."),
            QuizQuestion("e9", "Which TV series features the fictional continents of Westeros and Essos?", listOf("The Witcher", "Game of Thrones", "Lord of the Rings", "Wheel of Time"), 1, "Based on George R.R. Martin's books."),
            QuizQuestion("e10", "Who sang the viral hit song 'Blinding Lights'?", listOf("Drake", "The Weeknd", "Post Malone", "Bruno Mars"), 1, "The Weeknd released Blinding Lights in 2019.")
        ),
        "sports" to listOf(
            QuizQuestion("sp1", "How many players are on the pitch for one soccer team?", listOf("9", "10", "11", "12"), 2, "Each side fields 11 players including the goalkeeper."),
            QuizQuestion("sp2", "Which country has won the most FIFA World Cup titles?", listOf("Germany", "Italy", "Brazil", "Argentina"), 2, "Brazil has won 5 World Cup championships."),
            QuizQuestion("sp3", "What is the highest possible score in a single game of bowling?", listOf("250", "280", "300", "350"), 2, "Twelve consecutive strikes result in a 300 perfect game."),
            QuizQuestion("sp4", "In basketball, how many points is a free throw worth?", listOf("1", "2", "3", "0.5"), 0, "A standard free throw is worth 1 point."),
            QuizQuestion("sp5", "Where were the first modern Olympic Games held in 1896?", listOf("Paris", "Athens", "London", "Rome"), 1, "Athens, Greece hosted the inaugural modern Olympics."),
            QuizQuestion("sp6", "What is the length of an official marathon race?", listOf("40.0 km", "42.195 km", "45.5 km", "50.0 km"), 1, "42.195 kilometers (26.2 miles)."),
            QuizQuestion("sp7", "Which tennis tournament is played on grass courts?", listOf("Roland Garros", "US Open", "Wimbledon", "Australian Open"), 2, "Wimbledon is the prestigious grass court Grand Slam."),
            QuizQuestion("sp8", "In cricket, how many wickets does a fielding team need to dismiss an entire side?", listOf("8", "9", "10", "11"), 2, "A team has 11 batters, so 10 wickets ends the innings."),
            QuizQuestion("sp9", "Who holds the men's 100m world sprint record of 9.58 seconds?", listOf("Tyson Gay", "Usain Bolt", "Yohan Blake", "Carl Lewis"), 1, "Usain Bolt set the record in Berlin in 2009."),
            QuizQuestion("sp10", "How many holes are in a standard round of golf?", listOf("9", "12", "18", "21"), 2, "Regulation championship golf courses feature 18 holes.")
        )
    )

    fun getQuestionsForLevel(categoryId: String, level: Int): List<QuizQuestion> {
        val all = questionBank[categoryId] ?: questionBank["general"]!!
        // Deterministically shuffle/select 5 questions per level based on level offset
        val startIndex = ((level - 1) * 3) % all.size
        val result = mutableListOf<QuizQuestion>()
        for (i in 0 until 5) {
            val q = all[(startIndex + i) % all.size]
            result.add(q.copy(id = "${q.id}_lvl${level}"))
        }
        return result
    }
}
