::  mar/auspex-action: the blot the executor pokes auspex's writer with.
::
::    A guest distributes every marc it names, so this copy of auspex's
::    own marc lives here for the code tree's closure; the poke is a
::    bask the kernel validates where it is consumed, in auspex's
::    namespace, against auspex's copy. Both are a noun passthrough:
::    auspex's writer clams the action itself, under mule, so a
::    malformed one is refused rather than a fuse blown (the reasoning
::    is in auspex's marc). The layout the executor sends is the one
::    +poke-auspex names.
::
|_  n=*
++  grad  %noun
++  grow
  |%
  ++  noun  n
  --
++  grab
  |%
  ++  noun  *
  --
--
