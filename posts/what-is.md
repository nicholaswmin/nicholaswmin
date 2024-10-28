# what is this?

21-10-2021

This site is an example of minimalism in software design; otherwise 
known as **conciseness**. 

It's generated using a minimal site generator, called [nix][nix], 
which itself is ~150 lines of pure [ruby][ruby] code.

---

in common usage and linguistics, concision  (also called conciseness, 
succinctness,[^1] terseness, brevity, or laconicism) is a communication 
principle[^2] of eliminating redundancy,[^3] generally  achieved by using as 
few words as possible in a sentence while preserving its meaning. 

More generally, it is achieved through the omission of parts that 
impart information that was already given, that is obvious or that is 
irrelevant.  Outside of linguistics, a message may be similarly "dense" in 
other forms of communication.

In linguistic research, there have been approaches to analyze the level of 
succinctness of texts using semantic analysis.[^6]



> I have made this longer than usual, only because I have not 
> had the time to make it shorter.[^7]

[Blaise Pascal][bp]

> A sentence should contain no unnecessary words, a paragraph no unnecessary 
> sentences, for the same reason that a drawing should have no unnecessary 
> lines and a machine no unnecessary parts. This requires not that the writer 
> make all his sentences short, or that he avoid all detail and treat his 
> subjects only in outline, but that every word tell.

From [The Elements of Style][eos], [William Strunk][ws]

### Implementation

This blog has 3 pages:

- A post list, the authors CV and the **post itself**
 
- It is focused. it skips fluff and only includes the bare minimums.
- It does one thing but does it well. Semantic HTML, a tiny CSS file with
  respects for dark mode, 
  ARIA accessibility-standards checked, and above all it's tiny hyper 
  performant size.It's file size could be measured in bytes

What you've just read was filler text, half of it being complete bullshit. 
This page seems to render fine. 

Thanks for reading.

Heres a picture of Felix The Housecat to check how images render:

![An imae of Felix the Housecat, a cartoon](/public/felix.webp "Felix the Cat")


This project was inspired by: The [1kb club][1kb].
 
[1kb]: https://1kb.club/
[bp]: https://en.wikipedia.org/wiki/Blaise_Pascal
[eos]: https://en.wikipedia.org/wiki/The_Elements_of_Style
[ws]: https://en.wikipedia.org/wiki/William_Strunk_Jr.


### Footnotes



[^1]: Garner, Bryan A. (2009). Garner on Language and Writing: Selected Essays z
      and Speeches of Bryan A. Garner. Chicago: American Bar Association. p. 295. 
      ISBN 978-1-60442-445-4.

[^2]: William Strunk (1918). The Elements of Style.

[^3]: UNT Writing Lab. "Concision, Clarity, and Cohesion." 
      Accessed June 19, 2012. Link.

[^4]: Program for Writing and Rhetoric, University of Colorado at Boulder. 
      "Writing Tip #27: Revising for Concision and Clarity." 
      Accessed June 19, 2012. Link. Archived 2012-06-14 at the Wayback Machine 

      ""It is a fact that most arguments must try to convince readers, 
      that is the audience, that the arguments are true." Notice the beginning 
      of the sentence: "it is a fact that" doesn't say much; if something is a 
      fact, just present it. 
      So begin the sentence with "most arguments..." 
      and turn to the next bit of overlap. Look at "readers, that is 
      the audience"; the redundancy can be reduced to "readers" or "audience." 
      Now we have "Most arguments must try to convince readers that the 
      arguments are true." Let's get rid of one of the "arguments" to produce 
      "Most arguments must demonstrate (their) truth to readers," or a similarly 
      straightforward expression."

[^5]: Leslie Kurke, Aesopic Conversations: Popular Tradition, Cultural Dialogue, 
      and the Invention of Greek Prose, Princeton University Press, 2010, 
      pp. 131–2, 135.

[^6]: Lejeune, Anthony (2001). The Concise Dictionary of Foreign Quotations. 
      Taylor & Francis. p. 73. ISBN 9781579583415. OCLC 49621019.

[^7]: Moskey, Stephen T.; Williams, Joseph M. (March 1982). 
      "Style: Ten Lessons in Clarity and Grace". Language. 58 (1): 254. 
      doi:10.2307/413569. ISSN 0097-8507. JSTOR 413569. S2CID 33626209.
      
[^8]: Sandy Buczynski, Kristin Fontichiaro, Story Starters and 
      Science Notebooking: Developing Student Thinking Through
      Literacy and Inquiry (2009), p. 7, ISBN 1591586860.

[^9]:  Patrick Dunleavy, Authoring a PhD: 
      How to Plan, Draft, Write and Finish a Doctoral Thesis or 
      sDissertation (2003), p. 273, ISBN 023036800X.
      
      
      
[ruby]: https://www.ruby-lang.org/en/
[nix]: https://github.com/nicholaswmin/nix
