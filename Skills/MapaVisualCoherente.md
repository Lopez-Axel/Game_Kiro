# Skill: MapaVisualCoherente

## Descripción
Skill para el agente de desarrollo que garantiza la coherencia visual en mapas generados aleatoriamente a partir de `exploration.tscn`. Resuelve el problema de desorden visual donde los tiles se colocan sin contexto, confundiendo al jugador.

## Objetivo
Asegurar que cada tile del mapa generado use el sprite correcto según su **tipo funcional** y **relación con vecinos**, creando una experiencia visual clara y comprensible.

## Contexto de Assets

| Archivo | Tipo | Contexto de Uso |
|---------|------|-----------------|
| `actor.png` | otro | Sprite de personaje/NPC. **NO** usar para construir el mapa. |
| `ground_grass.png` | camino | Piso base para áreas transitables. |
| `object.png` | otro | Decoración independiente. No es suelo. |
| `obstacle.png` | obstáculo | Bloqueo sólido aislado. |
| `obstacle_corner.png` | obstáculo | Esquina exterior de bloque. |
| `obstacle_corner_inward.png` | obstáculo | Esquina interior (cavidad). |
| `obstacle_corner_outward.png` | obstáculo | Esquina exterior pronunciada. |
| `obstacle_edge.png` | obstáculo | Borde de obstáculo con suelo. |
| `obstacle_grass.png` | obstáculo | Borde orgánico entre obstáculo y hierba. |
| `obstacle_wall.png` | obstáculo | Muro largo y sólido. |
| `obstacle_wall_corner.png` | obstáculo | Esquina de muro. |
| `path_center.png` | camino | Centro de sendero principal. |
| `path_corner_noise_1.png` | camino | Curva con textura natural. |
| `path_edge.png` | camino | Borde de camino. |
| `path_edge_noise_1.png` | camino | Borde con variación visual. |
| `rock.png` | obstáculo | Roca decorativa o bloqueo pequeño. |

## Reglas de Asignación Visual

### Para Celdas de Tipo `camino`
| Condición de Vecinos | Sprite a Usar |
|----------------------|---------------|
| Todos los vecinos son camino | `path_center.png` |
| Tiene borde con obstáculo | `path_edge.png` o `path_edge_noise_1.png` |
| Forma esquina (cambio de dirección) | `path_corner_noise_1.png` |
| Borde con variación | `path_edge_noise_1.png` |

### Para Celdas de Tipo `obstáculo`
| Condición de Vecinos | Sprite a Usar |
|----------------------|---------------|
| Bloque aislado | `obstacle.png` |
| Forma muro (vecinos laterales) | `obstacle_wall.png` |
| Esquina exterior | `obstacle_corner.png` o `obstacle_corner_outward.png` |
| Esquina interior (hueco) | `obstacle_corner_inward.png` |
| Borde con camino | `obstacle_edge.png` |
| Borde con hierba | `obstacle_grass.png` |

### Para Celdas de Tipo `suelo` (fondo)
- Siempre usar: `ground_grass.png`

### Para Elementos Decorativos
- `object.png` y `rock.png` se colocan **sobre** el suelo, sin afectar navegación.
- Se asignan aleatoriamente en celdas de tipo `suelo` o `camino` (sin bloquear).

## Algoritmo de Generación

1. **Leer la matriz del mapa** generada en `exploration.tscn`.
2. **Clasificar cada celda** como `camino`, `obstáculo` o `suelo`.
3. **Analizar vecinos** (arriba, abajo, izquierda, derecha) de cada celda.
4. **Seleccionar el sprite** según las reglas definidas.
5. **Asignar el sprite** en la escena, respetando capas:
   - Capa 0: Suelo (`ground_grass.png`)
   - Capa 1: Caminos y obstáculos
   - Capa 2: Decoraciones (`object.png`, `rock.png`)
6. **Aplicar variaciones** opcionales para romper monotonía (ej. `path_corner_noise_1.png`).
7. **Validar visualmente** que no haya tiles mal ubicados.

## Implementación en GDScript (Godot)

```gdscript
extends Node2D

func asignar_sprite_segun_contexto(pos, matriz):
    var tipo = matriz[pos.x][pos.y]
    var vecinos = obtener_vecinos(pos, matriz)
    
    match tipo:
        "camino":
            if vecinos.todos_camino():
                return "path_center.png"
            elif vecinos.es_esquina():
                return "path_corner_noise_1.png"
            elif vecinos.tiene_borde():
                return "path_edge.png"
            else:
                return "path_edge_noise_1.png"
        
        "obstaculo":
            if vecinos.es_muro():
                return "obstacle_wall.png"
            elif vecinos.es_esquina_exterior():
                return "obstacle_corner.png"
            elif vecinos.es_esquina_interior():
                return "obstacle_corner_inward.png"
            elif vecinos.tiene_borde_con_camino():
                return "obstacle_edge.png"
            else:
                return "obstacle.png"
        
        "suelo":
            return "ground_grass.png"
        
        "decoracion":
            # Asignar aleatoriamente
            return "rock.png" if randf() > 0.5 else "object.png"

func obtener_vecinos(pos, matriz):
    # Retorna un diccionario con información de los 4 vecinos
    var vecinos = {
        "arriba": matriz[pos.x][pos.y-1] if pos.y > 0 else null,
        "abajo": matriz[pos.x][pos.y+1] if pos.y < matriz.size()-1 else null,
        "izquierda": matriz[pos.x-1][pos.y] if pos.x > 0 else null,
        "derecha": matriz[pos.x+1][pos.y] if pos.x < matriz[0].size()-1 else null
    }
    return vecinos