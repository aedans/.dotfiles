"""Bakes transforms into the shapes they move, rewriting the SVG files given as
arguments in place: a group's transform passes to its children, and a shape's
becomes a path in the transformed coordinates. GTK 4 draws nothing for a
symbolic icon's shape drawn through a transform.

Elements that clip, mask or reference others (use, text, image, or anything
with clip-path or mask) keep their transforms, which those depend on."""
import io
import math
import sys
import xml.etree.ElementTree as ET

from svgelements import SVG, Path, Shape

SVG_NS = "http://www.w3.org/2000/svg"
SHAPES = {"path", "rect", "circle", "ellipse", "line", "polyline", "polygon"}
GEOMETRY = {"d", "x", "y", "width", "height", "rx", "ry", "cx", "cy", "r",
            "x1", "y1", "x2", "y2", "points", "pathLength"}


def local(tag):
    return tag.rpartition("}")[2]


def keeps_transform(element):
    return "clip-path" in element.attrib or "mask" in element.attrib


def flattened(element, transform):
    """The element's shape as path data in its parent's coordinates, and how
    much the transform scales lengths, or None if svgelements can't place it."""
    alone = ET.Element(f"{{{SVG_NS}}}svg")
    copy = ET.SubElement(alone, element.tag,
                         {k: v for k, v in element.attrib.items() if k in GEOMETRY})
    copy.set("transform", transform)
    shapes = [e for e in SVG.parse(io.StringIO(ET.tostring(alone, encoding="unicode"))).elements()
              if isinstance(e, Shape)]
    if len(shapes) != 1:
        return None
    path = Path(shapes[0])
    path.reify()
    matrix = shapes[0].transform
    return path.d(), math.sqrt(abs(matrix.a * matrix.d - matrix.b * matrix.c))


def flatten(element, inherited=""):
    """Moves the transforms at and below element onto its shapes."""
    own = element.attrib.get("transform", "")
    transform = f"{inherited} {own}".strip()
    name = local(element.tag)
    if keeps_transform(element) or name not in SHAPES | {"g", "a", "svg"}:
        if transform:
            element.set("transform", transform)
        return
    if name in SHAPES:
        if not transform:
            return
        result = flattened(element, transform)
        if result is None:
            element.set("transform", transform)
            return
        d, scale = result
        for attribute in GEOMETRY | {"transform"}:
            element.attrib.pop(attribute, None)
        element.tag = f"{{{SVG_NS}}}path"
        element.set("d", d)
        if "stroke-width" in element.attrib:
            element.set("stroke-width", f"{float(element.get('stroke-width')) * scale:g}")
        return
    # The root svg's own coordinates are its viewBox, which isn't a transform.
    element.attrib.pop("transform", None)
    for child in element:
        if local(child.tag) not in {"defs", "clipPath", "mask", "symbol"}:
            flatten(child, transform)


ET.register_namespace("", SVG_NS)
ET.register_namespace("xlink", "http://www.w3.org/1999/xlink")
for file in sys.argv[1:]:
    tree = ET.parse(file)
    flatten(tree.getroot())
    tree.write(file, encoding="unicode")
