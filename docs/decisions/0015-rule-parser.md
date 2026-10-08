# ADR 0015: The rule parser reads big bare numbers as millimes and scores its own confidence

- Status: accepted
- Date: 2026-10-08
- Task: 5.4 (ARCHITECTURE.md §8)

## Context

Quick input reads phrases like "coffee 3.5 and taxi 8", "3.5 café w 8 taxi" or "kaskrout b 3500" in English, French and Darija in Latin letters. Rules come first. Only when the rules are unsure does the on-device LLM try (task 5.5). Three things needed deciding:

1. **How to read a bare number.** In Tunisia, small prices are often said in millimes: "kaskrout 3500" means 3.500 DT, not 3500 DT.
2. **When the rules are "unsure".** The LLM is slow, so it should only get the phrases the rules can't read.
3. **Darija in Latin letters uses digits as letters**: "9ahwa" (coffee), "3cha" (dinner), "5obz" (bread). Those can't be read as amounts.

## Decision

- **In TND, a bare whole number of 1000 or more is millimes** (decided with the user). "kaskrout 3500" is 3.500 DT and "kra 450" is 450 DT. Rent of 1000 DT or more needs a unit ("1200 dt"). Explicit units always win: "dt"/"dinars", "millimes"/"m", "3d500", "3 dinars w 500 millimes". Outside TND, numbers are never millimes. A millime guess costs a little confidence, so the confirmation sheet can draw the eye to it.
- **Confidence is a 0–100 score built from penalties**, and the phrase's score is its least sure item. The penalties:

  | Cause | Penalty |
  |---|---|
  | No label | −45 |
  | A label with no known word (`ExpenseKeywords`) | −15 |
  | A millime guess | −10 |
  | Words merged into an item | −25 |
  | A unit in another currency | −50 |

  Numbers in words ("trois", "khamsa", "nos"), words left with no amount, and amounts that can't be read set the whole phrase to 0. Below 60, the phrase goes to the LLM. The test set checks that no wrong reading scores 60 or more.
- **A token is an amount only if all of it is a number**, with an optional unit. "9ahwa" and "3cha" stay words.
- **Word order comes from the phrase.** If it starts with an amount, each amount takes the words after it; otherwise the words before it. Separators ("and/et/w/wa/o/puis/+/,/;") split items first.
- **The keyword list is shared.** It maps each word to a default category, and the categorizer (5.7) will use it as its rules tier.

## Consequences

- "café 900" reads as 900 DT. The confirmation sheet shows it and the user fixes it.
- Dates ("hier", "lyoum") are dropped as fillers. The confirmation sheet sets the date.
- Accuracy on the 61-phrase set is a regression guard, since I wrote the set alongside the rules. The real measure is the held-out set the user writes in 5.5.
