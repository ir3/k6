require 'js'

# --------------------------------------------
# Constants
#
# Copyright: p5.js(https://p5js.org/copyright.html)
# The p5.js library is free software;
# you can redistribute it and/or modify it under the terms of
# the GNU Lesser General Public License as published
# by the Free Software Foundation, version 2.1.
# --------------------------------------------
_PI = Math::PI

P2D   = 'p2d'
WEBGL = 'webgl'

# ENVIRONMENT
ARROW = 'default'
CROSS = 'crosshair'
HAND  = 'pointer'
MOVE  = 'move'
TEXT  = 'text'
WAIT  = 'wait'

# TRIGONOMETRY
HALF_PI    = _PI / 2
PI         = _PI
QUARTER_PI = _PI / 4
TAU        = _PI * 2
TWO_PI     = _PI * 2
DEGREES    = 'degrees'
RADIANS    = 'radians'
DEG_TO_RAD = _PI / 180.0
RAD_TO_DEG = 180.0 / _PI

CORNER  = 'corner'
CORNERS = 'corners'
RADIUS  = 'radius'
RIGHT   = 'right'
LEFT    = 'left'
CENTER  = 'center'
TOP     = 'top'
BOTTOM  = 'bottom'
BASELINE = 'alphabetic'

POINTS         = 0x0000
LINES          = 0x0001
LINE_STRIP     = 0x0003
LINE_LOOP      = 0x0002
TRIANGLES      = 0x0004
TRIANGLE_FAN   = 0x0006
TRIANGLE_STRIP = 0x0005

QUADS      = 'quads'
QUAD_STRIP = 'quad_strip'
TESS       = 'tess'
CLOSE      = 'close'
OPEN       = 'open'
CHORD      = 'chord'
PIE        = 'pie'
PROJECT    = 'square'
SQUARE     = 'butt'
ROUND      = 'round'
BEVEL      = 'bevel'
MITER      = 'miter'

# COLOR
RGB = 'rgb'
HSB = 'hsb'
HSL = 'hsl'

AUTO = 'auto'

# INPUT
ALT         = 18
BACKSPACE   = 8
CONTROL     = 17
DELETE      = 46
DOWN_ARROW  = 40
ENTER       = 13
ESCAPE      = 27
LEFT_ARROW  = 37
OPTION      = 18
RETURN      = 13
RIGHT_ARROW = 39
SHIFT       = 16
TAB         = 9
UP_ARROW    = 38

# RENDERING
BLEND      = 'source-over'
REMOVE     = 'destination-out'
ADD        = 'lighter'
DARKEST    = 'darken'
LIGHTEST   = 'lighten'
DIFFERENCE = 'difference'
SUBTRACT   = 'subtract'
EXCLUSION  = 'exclusion'
MULTIPLY   = 'multiply'
SCREEN     = 'screen'
REPLACE    = 'copy'
OVERLAY    = 'overlay'
HARD_LIGHT = 'hard-light'
SOFT_LIGHT = 'soft-light'
DODGE      = 'color-dodge'
BURN       = 'color-burn'

# FILTERS
THRESHOLD = 'threshold'
GRAY      = 'gray'
OPAQUE    = 'opaque'
INVERT    = 'invert'
POSTERIZE = 'posterize'
DILATE    = 'dilate'
ERODE     = 'erode'
BLUR      = 'blur'

# TYPOGRAPHY
NORMAL     = 'normal'
ITALIC     = 'italic'
BOLD       = 'bold'
BOLDITALIC = 'bold italic'
CHAR       = 'CHAR'
WORD       = 'WORD'

_DEFAULT_TEXT_FILL = '#000000'
_DEFAULT_LEADMULT  = 1.25
_CTX_MIDDLE        = 'middle'

# VERTICES
LINEAR    = 'linear'
QUADRATIC = 'quadratic'
BEZIER    = 'bezier'
CURVE     = 'curve'

# WEBGL
STROKE    = 'stroke'
FILL      = 'fill'
TEXTURE   = 'texture'
IMMEDIATE = 'immediate'
IMAGE     = 'image'
NEAREST   = 'nearest'
REPEAT    = 'repeat'
CLAMP     = 'clamp'
MIRROR    = 'mirror'

LANDSCAPE = 'landscape'
PORTRAIT  = 'portrait'

_DEFAULT_STROKE = '#000000'
_DEFAULT_FILL   = '#FFFFFF'

GRID     = 'grid'
AXES     = 'axes'
LABEL    = 'label'
FALLBACK = 'fallback'
CONTAIN  = 'contain'
COVER    = 'cover'

# --------------------------------------------
# Library
# --------------------------------------------

# JS::Object のプロパティ・メソッドを Ruby らしく呼べるようにする
class JS::Object
  def method_missing(sym, *args, &block)
    ret = self[sym]

    case ret.typeof
    when "undefined"
      str = sym.to_s
      if str[-1] == "="
        self[str.chop.to_sym] = args.first
        return args.first
      end
      super
    when "function"
      self.call(sym, *args, &block).to_r
    else
      ret.to_r
    end
  end

  def respond_to_missing?(sym, include_private)
    return true if super
    self[sym].typeof != "undefined"
  end

  # JS の値を Ruby の型に変換
  def to_r
    case self.typeof
    when "number" then self.to_f
    when "string" then self.to_s
    else self
    end
  end
end

# p5.js グローバル関数をそのまま呼べるようにする（全クラスに継承）
$p5 = nil

def method_missing(sym, *args, &block)
  return super unless $p5.respond_to?(:[])
  ret = $p5[sym]

  case ret.typeof
  when "undefined"
    super
  when "function"
    $p5.call(sym, *args, &block).to_r
  else
    ret.to_r
  end
end

module P5
  module_function

  def init(app)
    sketch = ->(p) {
      $p5 = p
      p[:setup]         = -> { app.setup         } if app.respond_to?(:setup)
      p[:draw]          = -> { app.draw          } if app.respond_to?(:draw)
      p[:mousePressed]  = -> { app.mousePressed  } if app.respond_to?(:mousePressed)
      p[:mouseReleased] = -> { app.mouseReleased } if app.respond_to?(:mouseReleased)
      p[:mouseMoved]    = -> { app.mouseMoved    } if app.respond_to?(:mouseMoved)
      p[:keyPressed]    = -> { app.keyPressed    } if app.respond_to?(:keyPressed)
      p[:keyReleased]   = -> { app.keyReleased   } if app.respond_to?(:keyReleased)
    }
    container = JS.global[:__p5_container]
    inst = container.typeof == "undefined" ?
      JS.global[:p5].new(sketch) :
      JS.global[:p5].new(sketch, container)
    JS.global[:__p5_instance] = inst
  end

  def vector(x, y, z = 0)
    JS.global[:p5][:Vector].new(x, y, z)
  end
end
