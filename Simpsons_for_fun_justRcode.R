## ---- echo=FALSE, message=FALSE, warning=FALSE---------------------------
#Load packages 
library(ggplot2)
library(dplyr)
library(tidyr)
library(lubridate)
library(GGally)
library(gridExtra)
library(ggrepel)

## ----global_options, include=FALSE---------------------------------------
#set global chunk options
knitr::opts_chunk$set(fig.width=10, fig.height=6, echo=FALSE, warning=FALSE, message=FALSE)

## ------------------------------------------------------------------------
#datasets include longs strings; let's make sure R interprets them as character vectors
options(stringsAsFactors = FALSE)
#set a default theme for plots
theme_set(theme_bw())

## ------------------------------------------------------------------------
#import the 4 csv files composing the data
#first attempt at this led to some parsing errors
#so using excel I removed all commas from cells in the 'episodes' and 'script_lines' files

#records every character with a unique id
simp.characters <- read.csv(file = "data/simpsons_characters.csv") 

#contains data on each episode
simp.episodes <- read.csv(file = "data/simpsons_episodes2.csv") 

#contains data on locations in the show
simp.location <- read.csv(file = "data/simpsons_locations.csv") 

#contains the script of each episode and who is speaking
simp.words <- read.csv(file = "data/simpsons_script_lines2.csv") 

#show data for the two smallest tables
head(simp.characters)
head(simp.location)

## ------------------------------------------------------------------------
#show episode-level data
head(simp.episodes)

## ------------------------------------------------------------------------
#show main data
head(simp.words)
dim(simp.words) #dimensions of main data

## ------------------------------------------------------------------------
#select necessary columns in each of 4 dataframes
simp.characters <- select(simp.characters, -name)
simp.location <- select(simp.location, -name)
simp.episodes <- select(simp.episodes, -production_code, -image_url, -video_url)
simp.words <- select(simp.words, id, episode_id, number, speaking_line, character_id,
                     location_id, normalized_text, word_count)
head(simp.episodes)

## ------------------------------------------------------------------------
#check class of each column
sapply(simp.characters, class)
sapply(simp.location, class)

## ------------------------------------------------------------------------
sapply(simp.episodes, class) 

## ------------------------------------------------------------------------
#the variable is in month-day-year format, so use the 'mdy' function to convert it to a date
simp.episodes$original_air_date <- mdy(simp.episodes$original_air_date) 

#extract the month and year of each episode and make new variables
simp.episodes$air_year <- year(simp.episodes$original_air_date)
simp.episodes$air_month <- month(simp.episodes$original_air_date)
head(select(simp.episodes, original_air_date, air_month, air_year))

## ------------------------------------------------------------------------
sapply(simp.words, class)

## ------------------------------------------------------------------------
#subset data to show cases where word_count does not start with digit 
filter(simp.words, grepl('\\D', word_count))

## ------------------------------------------------------------------------
#only take rows that start with digit
simp.words <- filter(simp.words, grepl('\\d', word_count))%>% 
  mutate(word_count = as.numeric(word_count)) #make it numeric
sapply(simp.words, class)

## ------------------------------------------------------------------------
dim(simp.words) #dimensions of simplified data
table(simp.words$speaking_line)

## ------------------------------------------------------------------------
ggplot(simp.words, aes(x = word_count)) + geom_histogram()

## ------------------------------------------------------------------------
filter(simp.words, word_count > 1000)

## ------------------------------------------------------------------------
simp.words <- filter(simp.words, word_count < 1000)
ggplot(simp.words, aes(x = word_count)) + geom_histogram(binwidth = 1)

## ------------------------------------------------------------------------
ggplot(simp.words, aes(x = word_count)) + geom_histogram(binwidth = 1) +
  xlim(c(40, 120))

## ------------------------------------------------------------------------
#recalculate words per spoken part
simp.words <- mutate(simp.words, words_recalc = 
                        unlist(lapply(strsplit(normalized_text, split = " "), length)))
#are original word counts are recalculated word counts congruent?
select(simp.words, word_count, words_recalc)[1:10,] 

## ------------------------------------------------------------------------
#plot word_count versus recalculated word count to see if they fall on a straight line
ggplot(simp.words, aes(x = word_count, y = words_recalc)) + geom_point(alpha = 0.1)

## ------------------------------------------------------------------------
#look at cases where original word counts and recalculated word counts differ
filter(simp.words, word_count != words_recalc)%>%
  select(episode_id, character_id, normalized_text, word_count, words_recalc)
#remove the cases where they differ
simp.words <- filter(simp.words, word_count == words_recalc)

## ------------------------------------------------------------------------
#calculate total words spoken per character in each episode
simp.words.red <- group_by(simp.words, episode_id, character_id)%>%
  summarize(words_in_episode = sum(word_count))
head(simp.words.red)

## ------------------------------------------------------------------------
#create matching vector (mv) to add character data into main script dataset
mv <- match(simp.words.red$character_id, simp.characters$id)

#combine character data and main script data
combined.df <- cbind(ungroup(simp.words.red), simp.characters[mv,])
#remove redundant character id variable
combined.df <- select(combined.df, -id)
head(combined.df)

## ------------------------------------------------------------------------
#same approach for combining datasets as in last chunk, this time for episode data
mv <- match(simp.words.red$episode_id, simp.episodes$id)
combined.df <- cbind(combined.df, simp.episodes[mv,])
combined.df <- select(combined.df, -id)
rownames(combined.df) <- 1:dim(combined.df)[1]
rm(mv)
head(combined.df)

## ------------------------------------------------------------------------
ggplot(combined.df, aes(x = words_in_episode)) + geom_histogram(binwidth= 10)
summary(combined.df$words_in_episode)

## ------------------------------------------------------------------------
#take a random sample of 10 Simpsons characters
set.seed(5)
rand.characters <- sample(x = unique(combined.df$normalized_name), size = 10)

#plot how much they speak per episode
ggplot(filter(combined.df, normalized_name %in% rand.characters),
       aes(x = normalized_name, y = words_in_episode)) + 
  geom_point() + coord_flip()

## ------------------------------------------------------------------------
#table of number of episodes in which each character speaks 
episodes_per_character <- sort(table(combined.df$normalized_name), decreasing = TRUE)
#histogram of table
qplot(as.numeric(episodes_per_character), binwidth = 1)

## ------------------------------------------------------------------------
qplot(as.numeric(episodes_per_character), binwidth = 1) + xlim(0, 5)

## ------------------------------------------------------------------------
qplot(as.numeric(episodes_per_character), binwidth = 10) + xlim(50, 600)

## ------------------------------------------------------------------------
#which characters occur in over 500 episodes
episodes_per_character[which(episodes_per_character>500)]

## ------------------------------------------------------------------------
#take the 10 characters occurring in the most episodes for plot
main.characters <- names(episodes_per_character)[1:10]

ggplot(filter(combined.df, normalized_name %in% main.characters),
       aes(y = normalized_name, x = words_in_episode)) + 
  geom_point(alpha = 0.2)

## ------------------------------------------------------------------------
ggplot(filter(combined.df, normalized_name %in% main.characters),
       aes(x = normalized_name, y = words_in_episode)) + 
  geom_boxplot() + coord_flip()

## ------------------------------------------------------------------------
#calculate total number of words spoken for each character, arrange data by words spoken
words_by_character <- group_by(combined.df, normalized_name)%>%
  summarize(total_words_spoken = sum(words_in_episode))%>%
  arrange(desc(total_words_spoken))

#create a factor variable with levels in correct order
words_by_character$character_name <- factor(words_by_character$normalized_name, 
                                            levels = rev(words_by_character$normalized_name))
#plot 20 characters with most spoken text
ggplot(words_by_character[1:20,], 
       aes(x = character_name, y = total_words_spoken)) +
  geom_bar(stat = 'identity') + coord_flip()

#calculate and show proportion of total text in series spoken by each character
total_words <- sum(words_by_character$total_words_spoken)
cbind(name = words_by_character$normalized_name[1:20],
      prop_total_words = round(digits = 4, 
                               words_by_character$total_words_spoken[1:20] / total_words))

## ------------------------------------------------------------------------
#add gender to the data frame with the 'total words spoken' variable
mv <- match(words_by_character$normalized_name, combined.df$normalized_name)
words_by_character$gender <- combined.df$gender[mv]
rm(mv)

#re-plot but color bars by gender
ggplot(words_by_character[1:20,], 
       aes(x = character_name, y = total_words_spoken)) +
  geom_bar(aes(fill = gender), stat = 'identity') +
  coord_flip()

## ------------------------------------------------------------------------
#combine episodes_per_character table with data frame containing total words spoken
mv <- match(words_by_character$normalized_name, names(episodes_per_character))
words_by_character$number_of_episodes <- as.numeric(episodes_per_character)[mv]

#plot the number of episodes vs total dialog for the 30 most important characters
ggplot(words_by_character[1:30,],
       aes(x = number_of_episodes, y = total_words_spoken)) +
  geom_smooth(method = 'lm', se = F) + 
  geom_point() +
  geom_text_repel(aes(label = character_name)) +
  scale_y_log10()

## ------------------------------------------------------------------------
ggplot(words_by_character[1:30,],
       aes(x = number_of_episodes, y = total_words_spoken)) +
  geom_smooth(method = 'lm', se = F) + 
  geom_point() +
  geom_text_repel(data = words_by_character[5:30,],
                  aes(label = character_name)) +
  coord_cartesian(xlim = c(0,400), ylim = c(3500,40000)) +
  scale_y_log10()

## ------------------------------------------------------------------------
#note the 10 characters with the most dialog overall
main.characters <- words_by_character$normalized_name[1:10] 
#plot their dialog per episode over time
ggplot(filter(combined.df, normalized_name %in% main.characters),
       aes(x = original_air_date, y = words_in_episode, color = normalized_name)) +
  geom_point(alpha = 0.2) +
  geom_smooth(se=F)

## ------------------------------------------------------------------------
#only plot the Simpsons family
ggplot(filter(combined.df, normalized_name %in% main.characters[1:4]),
       aes(x = original_air_date, y = words_in_episode, color = normalized_name)) +
  geom_point(alpha = 0.2) +
  geom_smooth(se=F) + scale_y_log10()
#only plot non-Simpsons
ggplot(filter(combined.df, normalized_name %in% main.characters[5:10]),
       aes(x = original_air_date, y = words_in_episode, color = normalized_name)) +
  geom_point(alpha = 0.2) +
  geom_smooth(se=F) + scale_y_log10()

## ------------------------------------------------------------------------
#note the 30 characters with the most dialog overall
main.characters <- words_by_character$normalized_name[1:30]
#plot dialog per episode over time, pooling top characters together
ggplot(filter(combined.df, normalized_name %in% main.characters),
       aes(x = original_air_date, y = words_in_episode)) +
  geom_smooth(se=T) 

## ------------------------------------------------------------------------
#calculate number of characters that speak per episode
characters_per_episode <- group_by(combined.df, episode_id, original_air_date)%>%
  summarize(char_per_episode = n())
#plot it over time
ggplot(characters_per_episode,
       aes(x = original_air_date, y = char_per_episode)) +
  geom_smooth(se=T) 

## ------------------------------------------------------------------------
#put the data in long format; limit data to core Simpson family
episode_by_character_long <- filter(combined.df, 
                                    normalized_name %in% main.characters[1:4])%>%
  select(episode_id, normalized_name, words_in_episode)%>%
  spread(key = normalized_name, value = words_in_episode)

#remake variable names, replacing whitespace with underscore
names(episode_by_character_long) <- gsub(" ", "_", names(episode_by_character_long))

head(episode_by_character_long)

## ------------------------------------------------------------------------
ggpairs(select(episode_by_character_long, -episode_id))

## ------------------------------------------------------------------------
simp_model <- lm(homer_simpson ~ marge_simpson + bart_simpson + lisa_simpson,
          data = episode_by_character_long)
summary(simp_model)

## ------------------------------------------------------------------------
ggplot(simp.episodes, aes(x = original_air_date, y = imdb_rating)) +
  geom_point() + geom_smooth()
#calculate mean IMDB rating pre and post 2000
simp.episodes$split_year_2000 <- "pre-2000"
simp.episodes$split_year_2000[which(simp.episodes$air_year>1999)] <- "post-2000"
with(simp.episodes, tapply(imdb_rating, split_year_2000, mean, na.rm=T))

## ------------------------------------------------------------------------
#the top rated episodes, having a IMDB rating over 8.9
filter(simp.episodes, imdb_rating > 8.9)%>%
  select(title, imdb_rating)%>%arrange(desc(imdb_rating))

## ------------------------------------------------------------------------
ggplot(simp.episodes, aes(x = imdb_votes)) + geom_histogram(binwidth = 100)
ggplot(simp.episodes, aes(x = imdb_votes, y = imdb_rating)) + geom_point()
with(simp.episodes, cor.test(imdb_votes, imdb_rating))

## ------------------------------------------------------------------------
#plot dialog per episode against imdb_ratings for core Simpson family
ggplot(filter(combined.df, normalized_name %in% main.characters[1:4]),
       aes(x = imdb_rating, y = words_in_episode)) +
  geom_point(alpha = 0.3) + geom_smooth() +
  facet_wrap(~normalized_name, scales = "free_y")

## ------------------------------------------------------------------------
#identify quantiles for top 5% of episodes
cut.pts <- quantile(simp.episodes$imdb_rating, probs = c(0, 0.95, 1), na.rm=T)

#create new factor variable
simp.episodes$imdb_cat <- cut(simp.episodes$imdb_rating, cut.pts)
simp.episodes$imdb_cat <- factor(simp.episodes$imdb_cat, labels = c("non-classic", "classic"))
rm(cut.pts)

#table of classic vs non-classic episodes
table(simp.episodes$imdb_cat) 

## ------------------------------------------------------------------------
#add classic vs non-classic discrete variable to main data
mv <- match(combined.df$episode_id, simp.episodes$id)
combined.df$imdb_cat <- simp.episodes$imdb_cat[mv]
rm(mv)

ggplot(filter(combined.df, normalized_name %in% main.characters[1:4], !is.na(imdb_cat)),
       aes(fill = imdb_cat, y = words_in_episode, x = normalized_name)) +
  geom_boxplot() 

## ------------------------------------------------------------------------
#calculate total number of words in episode
total_words_in_episode <- group_by(combined.df, episode_id)%>%
  summarize(total_words = sum(words_in_episode))

#add to main data table
combined.df$total_words_in_episode <- total_words_in_episode$total_words[
  match(combined.df$episode_id, total_words_in_episode$episode_id)]

#create variable for proportion of words in episode spoken by character
combined.df <- mutate(combined.df, proportion_dialog_per_episode = words_in_episode/total_words_in_episode)

#re-plot comparison of classic vs non-classic
ggplot(filter(combined.df, normalized_name %in% main.characters[1:4], !is.na(imdb_cat)),
       aes(fill = imdb_cat, y = proportion_dialog_per_episode, x = normalized_name)) +
  geom_boxplot() 

## ------------------------------------------------------------------------
#rearrange data for regression
logreg_data <- filter(combined.df, 
                      normalized_name %in% main.characters[1:4], !is.na(imdb_cat))%>%
  select(episode_id, imdb_cat, normalized_name, proportion_dialog_per_episode)%>%
  spread(key = normalized_name, value = proportion_dialog_per_episode)

#remake variable names, replacing whitespace with underscore
names(logreg_data) <- gsub(" ", "_", names(logreg_data))

#make dummy variable for whether an episode is or is not a classic
logreg_data$classic_dummy <- 0
logreg_data$classic_dummy[
  which(logreg_data$imdb_cat == "classic")] <- 1


#fit logistic regression
model_classic <- glm(classic_dummy ~ homer_simpson + marge_simpson +
                       bart_simpson + lisa_simpson,
                     data = logreg_data, family = "binomial")
summary(model_classic)

## ------------------------------------------------------------------------
with(logreg_data, tapply(homer_simpson, imdb_cat, mean, na.rm=T))
with(logreg_data, tapply(marge_simpson + bart_simpson + lisa_simpson, imdb_cat, mean, na.rm=T))


## ------------------------------------------------------------------------
ggplot(simp.episodes, aes(x = original_air_date, y = imdb_rating, color = imdb_cat)) +
  geom_point()

## ---- Plot_One-----------------------------------------------------------
#make first letters in character names uppercase
split_by_space <- strsplit(words_by_character$normalized_name, " ")
words_by_character$character_name_upper <- unlist(
  lapply(split_by_space,
         function(x) paste(toupper(substring(x, 1,1)),
                           substring(x, 2), sep="", collapse=" ")))

words_by_character$character_name_upper <- 
  factor(words_by_character$character_name_upper,
         levels = rev(words_by_character$character_name_upper))

ggplot(words_by_character[1:20,], 
       aes(x = character_name_upper, y = total_words_spoken)) +
  geom_bar(aes(fill = gender), stat = 'identity') +
  scale_y_continuous(breaks = c(0, 100000, 200000),
                     labels = c("0", "100,000", "200,000")) +
  scale_fill_manual(values = c("pink", "lightblue"),
                    labels = c("Female", "Male")) +
  labs(y = "Total number of words spoken", 
       title = "Amount of dialog, top 20 Simpsons characters") +
  theme(legend.position = c(1,0),
        legend.justification = c(1,0),
        legend.title = element_blank(),
        axis.title.y = element_blank(),
        panel.grid.minor = element_blank(),
        panel.grid.major.y = element_blank()) +
  coord_flip()

## ---- Plot_Two-----------------------------------------------------------
#homer vs marge dialog per episode
p1 <- ggplot(episode_by_character_long,
             aes(x = homer_simpson, y = marge_simpson)) +
  geom_point(shape = 1, color = "lightgreen") + 
  geom_smooth(se = F, color = "black", linetype = "dotted") +
  labs(x = "Words spoken by Homer",
       y = "Words spoken by Marge",
       title = "Dialog per episode") +
  scale_x_continuous(breaks = seq(0, 2000, 200)) +
  scale_y_continuous(breaks = seq(0, 2000, 200)) +
  theme(panel.grid.minor = element_blank())

#homer vs bart dialog per episode
p2 <- ggplot(episode_by_character_long,
             aes(x = homer_simpson, y = bart_simpson)) +
  geom_point(shape = 1, color = "tomato") + 
  geom_smooth(se = F, color = "black", linetype = "dotted") +
  labs(x = "Words spoken by Homer",
       y = "Words spoken by Bart",
       title = "Dialog per episode") +
  scale_x_continuous(breaks = seq(0, 2000, 200)) +
  scale_y_continuous(breaks = seq(0, 2000, 200)) +
  theme(panel.grid.minor = element_blank())

grid.arrange(p1, p2, ncol = 2)

## ---- Plot_Three---------------------------------------------------------
#make first letters in character names uppercase
split_by_space <- strsplit(combined.df$normalized_name, " ")
combined.df$character_name_upper <- unlist(
  lapply(split_by_space,
         function(x) paste(toupper(substring(x, 1,1)),
                           substring(x, 2), sep="", collapse=" ")))
#make character name an ordered factor for plot
combined.df$character_name_upper <- 
  factor(combined.df$character_name_upper,
         levels = rev(words_by_character$character_name_upper))

ggplot(filter(combined.df, normalized_name %in% main.characters[1:4],
                    !is.na(imdb_cat)),
       aes(x = character_name_upper, 
           y = proportion_dialog_per_episode, 
           fill = imdb_cat)) +
  geom_boxplot(outlier.shape = 1) +
  scale_fill_manual(values = c("white", "yellow"),
                    labels = c("Typical", "Classic")) +
  labs(y = "Proportion of dialog per episode",
       title = "Relative dialog in typical vs classic episodes") +
  theme(axis.title.x = element_blank(),
        legend.title = element_blank())

