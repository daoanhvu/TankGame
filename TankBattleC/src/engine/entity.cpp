#include "entity.h"

int Entity::getId() const {
  return this->id;
}

glm::vec2 Entity::getPosition() const {
  return this->position;
}