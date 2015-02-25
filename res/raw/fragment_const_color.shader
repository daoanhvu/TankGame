precision mediump float;
uniform vec3 uLightPos; //Light position in eyes space
varying vec3 vNormalInE;
varying vec3 vPositionInE;
varying vec4 vColor;
void main() {
	float distance;
	vec3 lightVector;
	float diffuse;
	
	distance = length(uLightPos - vPositionInE); //used for attenuation
	lightVector = normalize(uLightPos - vPositionInE);
	if(gl_FrontFacing) {
		diffuse = max(dot(vNormalInE, lightVector), 0.0);
	} else {
		diffuse = max(dot(-vNormalInE, lightVector), 0.0);
	}
		
	//Add attenuation and ambient
	diffuse = diffuse * (1.0 / (1.0 + (0.10 * distance))) + 0.5;
		
	gl_FragColor = vColor * diffuse;
}