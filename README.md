# Perl Gibberish Detector
I wrote this program after seeing similar projects done in PHP and Python... Originally, the idea comes from a question on stackoverflow (http://stackoverflow.com/questions/6297991/is-there-any-way-to-detect-strings-like-putjbtghguhjjjanika/6298040#comment-7360747).

# Usage

First train the model:

perl gib_detect_train.pl

Then try it on some sample input

perl gib_detect.pl

this is a sample sentence True

is this thing working? True

a lonely fox True

t2 chhsdfitoixcv False

ytjkacvzw False

yutthasxcvqer False

seems okay True

yay! True

# How it works

Credits to rrenaud for the explanation.

The markov chain first 'trains' or 'studies' a few MB of English text, recording how often characters appear next to each other. Eg, given the text "Rob likes hacking" it sees Ro, ob, o[space], [space]l, ... It just counts these pairs. After it has finished reading through the training data, it normalizes the counts. Then each character has a probability distribution of 27 followup character (26 letters + space) following the given initial.

So then given a string, it measures the probability of generating that string according to the summary by just multiplying out the probabilities of the adjacent pairs of characters in that string. EG, for that "Rob likes hacking" string, it would compute prob['r']['o'] * prob['o']['b'] * prob['b'][' '] ... This probability then measures the amount of 'surprise' assigned to this string according the data the model observed when training. If there is funny business with the input string, it will pass through some pairs with very low counts in the training phase, and hence have low probability/high surprise.

I then look at the amount of surprise per character for a few known good strings, and a few known bad strings, and pick a threshold between the most surprising good string and the least surprising bad string. Then I use that threshold whenever to classify any new piece of text.
