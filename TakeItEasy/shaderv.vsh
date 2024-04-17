attribute vec4 position;
attribute vec2 textCoordinate;
varying vec2 varyTextCoord;

void main()
{
    varyTextCoord = textCoordinate;
    gl_Position = position;
}
