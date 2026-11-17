# Keys den reads inside any aspect as pipeline machinery, class content or
# quirk data, never as child aspects.
{ den }:
k:
den.lib.aspects.fx.keyClassification.isStructuralKey k
|| (den.classes or { }) ? ${k}
|| (den.quirks or { }) ? ${k}
