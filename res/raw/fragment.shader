precision mediump float;
uniform vec3 uLightPos; //Light position in eyes space
varying vec4 vColor;
varying vec3 vNormalInE;
varying vec3 vPositionInE;
void main() {
	float distance = length(uLightPos - vPositionInE); //used for attenuation
	vec3 lightVector = normalize(uLightPos - vPositionInE);
	float diffuse;

	if(gl_FrontFacing) {
		diffuse = max(dot(vNormalInE, lightVector), 0.0);
	} else {
		diffuse = max(dot(-vNormalInE, lightVector), 0.0);
		//gl_BackColor = vColor * diffuse;
	}
	
	//Add attenuation and ambient
	diffuse = diffuse * (1.0 / (1.0 + (0.10 * distance))) + 0.5;
	
	gl_FragColor = vColor * diffuse;
}