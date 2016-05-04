precision mediump float;
uniform mat4 uModelView;
uniform mat4 uMVP;
attribute vec4 aPosition; 
attribute vec3 aNormal;
attribute vec4 aColor;
varying vec3 vPositionInE; //vertex in eye space
varying vec3 vNormalInE;
varying vec4 vColor;
void main() {
	vColor = aColor;
	
	//Transform the vertex into eye space
	vPositionInE = vec3(uModelView * aPosition);
	//Transform normal vector into eye space
	vNormalInE = vec3(uModelView * vec4(aNormal, 0.0));
	
	gl_Position = uMVP * aPosition;
}