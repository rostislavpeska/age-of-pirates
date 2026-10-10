# J7: railing with a corner post

- `Deck`: closed box, x 0 to 4, y 0 to 3, z 0.8 to 0.9.
- `Post.1` to `Post.5`: closed boxes 0.09 x 0.09 in plan, z 0.9 to 1.9, standing on the deck, centred at
  (0.045, 0.045), (2.0, 0.045), (3.955, 0.045) (the corner), (3.955, 1.5) and (3.955, 2.955).
- Rails: closed boxes 0.06 m deep and 0.08 m high, centred on the line through the post centres, two between each
  pair of neighbouring posts: a top rail (z 1.76 to 1.84) and a bottom rail (z 1.01 to 1.09). Name them
  `Rail.1.Top`, `Rail.1.Bottom` (posts 1-2), `Rail.2.*` (posts 2-3), `Rail.3.*` (posts 3-4), `Rail.4.*` (posts 4-5).

Each rail runs from the face of one post to the face of the next: both ends touch their posts (gap at most 5 mm),
at most 2 cm into a post, and no rail stands out beyond the faces of the posts it joins. Each post's foot sits fully
on the deck.
