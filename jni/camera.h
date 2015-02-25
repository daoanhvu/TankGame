#ifndef _CAMERA_H
#define _CAMERA_H

#include <gm.hpp>

namespace fp {
	class Camera {
	private:
		gm::mat4 mvp;
		gm::mat4 view;
		gm::mat4 model;
		gm::mat4 perspective;
		gm::mat4 orthor;
		float viewport[4];

		float centerX;
		float centerY;
		float centerZ;

		float eyeX;
		float eyeY;
		float eyeZ;

		gm::vec3 up;

		float pitchAccum;
		float yawAccum;
		float rollAccum;

	public:
		Camera();
		~Camera() {}

		//void setModelMatrix(float *mm);
		//void setViewMatrix(float *vm);

		void lookAt(float ex, float ey, float ez,
					float cx, float cy, float cz, float ux, float uy, float uz);
		void setPerspective(float fov, float nearPlane, float farPlane);
		void setOrtho(float left, float top, float right, float bottom);
		void rotate(float yaw, float pitch, float roll);
		void setViewport(int left, int top, int right, int bottom);
		void project(float *out, const float *obj);
		void project(float *out, float objX, float objY, float objZ);
		void projectOrthor(float *out, const float *obj);
		void projectOrthor(float *out, float objX, float objY, float objZ);

		//on testing method
		void moveAlongForward(float d);
#ifdef _DEBUG
		gm::mat4 getView() { return view; }
		gm::mat4 getPerspective() { return perspective; }
#endif
	};
}

#endif
