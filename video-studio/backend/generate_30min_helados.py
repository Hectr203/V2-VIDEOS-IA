#!/usr/bin/env python3
import asyncio
import os
import sys
import time
import json
import math
from services.voice_hub import VoiceHub
from services.project_manager import ProjectManager
from services.render_service import render_project

# 30 minutos de documental completo sobre la ciencia, historia y fabricación del helado
# 60 escenas de aproximadamente 30 segundos cada una = 1800 segundos (30.0 minutos)
TOPICS = [
    # Bloque 1: El origen histórico y el hielo antiguo (Escenas 1-10)
    ("El Hielo de los Reyes Antiguos", "Mucho antes de que existieran los congeladores eléctricos, los emperadores de la antigua China mezclaban nieve de montaña con leche de yaka y arroz fermentado, creando el primer antepasado documentado de lo que hoy llamamos helado."),
    ("Alejandro Magno y los Pozos de Nieve", "En la antigua Grecia, Alejandro Magno mandaba construir gigantescos pozos subterráneos forrados con paja y ramas para conservar nieve fresca traída de las cumbres durante los sofocantes veranos de sus campañas militares."),
    ("El Gran Salto de Marco Polo", "Cuando Marco Polo regresó a Venecia tras sus legendarias travesías por Asia, trajo consigo recetas secretas de postres helados elaborados con leche, despertando la fascinación absoluta en las cortes del Renacimiento italiano."),
    ("La Revolución de Catalina de Médici", "Al casarse con el futuro rey Enrique Segundo de Francia en el siglo dieciséis, Catalina de Médici llevó a París a sus propios reposteros italianos, introduciendo por primera vez las cremas heladas en la alta nobleza europea."),
    ("El Primer Café Heladero de París", "En el año dieciséis ochenta y seis abrió sus puertas en París el famoso Café Procope, el primer establecimiento público del mundo donde cualquier ciudadano distinguido podía disfrutar de copas de helado y sorbetes artesanos."),
    ("La Sal: El Descubrimiento Físico", "La gran revolución de la heladería no fue culinaria sino física: el descubrimiento de que agregar sal común al hielo baja su punto de fusión a más de diez grados bajo cero, permitiendo congelar líquidos sin diluirlos."),
    ("La Ley Termodinámica de la Salmuera", "Cuando la sal se disuelve en agua helada, absorbe energía térmica del ambiente en un proceso endotérmico instantáneo. Esto congela velozmente cualquier recipiente que esté sumergido en esa salmuera mágica."),
    ("Nancy Johnson y la Primera Manivela", "En el año mil ochocientos cuarenta y tres, una brillante inventora estadounidense llamada Nancy Johnson patentó la primera heladera de manivela manual, democratizando la elaboración del helado en miles de hogares."),
    ("El Nacimiento del Cono de Barquillo", "Durante la Feria Mundial de San Luis en mil novecientos cuatro, un vendedor de helados se quedó sin platos y un panadero sirio vecino enrolló sus gofres crujientes en forma de cono, inventando el barquillo moderno."),
    ("La Era de la Refrigeración Eléctrica", "La llegada del compresor de gas y la refrigeración eléctrica a principios del siglo veinte transformó el helado de un lujo aristocrático en la golosina universal más amada del planeta."),

    # Bloque 2: La ciencia de la base láctea y materias primas (Escenas 11-20)
    ("La Tríada de la Leche", "Todo helado de primera categoría comienza con tres componentes esenciales: agua pura contenida en la leche, grasa butírica de crema y sólidos lácteos desgrasados que aportan proteínas estructurales."),
    ("El Papel Crucial de la Grasa", "La grasa butírica de la leche no solo aporta suntuosidad al paladar, sino que recubre las microburbujas de aire y retrasa la velocidad a la que el helado se derrite cuando entra en contacto con tu boca."),
    ("Los Sólidos Lácteos No Grasos", "El suero y la caseína absorben parte del agua libre disponible. Si hay muy pocos sólidos el helado queda acuoso, pero si hay demasiados, la lactosa cristaliza como granos de arena molestos."),
    ("La Sacarosa y el Dulzor Equilibrado", "El azúcar tradicional de caña o remolacha no solo endulza: reduce el punto de congelación del agua. Sin azúcar, la mezcla sería un ladrillo de hielo rígido completamente incomible."),
    ("Glucosa y Dextrosa al Rescate", "Los maestros heladeros combinan varios tipos de azúcares con diferente poder anticongelante y dulzor, logrando que el helado se mantenga suave a dieciocho grados bajo cero sin ser empalagoso."),
    ("El Dilema de la Tensión Superficial", "La grasa y el agua son enemigos naturales debido a sus polaridades opuestas. Para evitar que la crema se separe y suba a la superficie, la física molecular debe intervenir de inmediato."),
    ("La Función de los Emulsionantes", "Moléculas con un extremo hidrófilo y otro lipófilo, como las lecitinas de yema de huevo o los mono y diglicéridos, actúan como puentes atómicos que unen grasa y agua en perfecta armonía."),
    ("Estabilizantes Naturales de la Naturaleza", "Gomas botánicas obtenidas de semillas de algarrobo y guar atrapan las moléculas de agua libres, evitando que se unan entre sí para formar cristales gigantescos con el paso de los días."),
    ("El Cálculo Preciso de la Receta", "La heladería moderna es pura matemática de precisión: cada gramo de grasa, azúcar, agua y sólidos totales debe calcularse en hojas de formulación antes de verter un solo litro de leche."),
    ("El Mezclado Térmico Inicial", "En gigantescos tanques de acero con camisas térmicas, los polvos secos se dispersan en los líquidos a cincuenta grados centígrados para garantizar una disolución molecular uniforme."),

    # Bloque 3: Pasteurización y Homogeneización (Escenas 21-30)
    ("La Pasteurización de Seguridad", "La mezcla líquida se calienta a ochenta y cinco grados durante unos segundos para destruir cualquier bacteria patógena y desenrollar las proteínas del suero lácteo."),
    ("La Activación de los Hidrocoloides", "El calor no solo esteriliza: activa las gomas estabilizantes, que necesitan alcanzar temperaturas elevadas para hidratarse al máximo y formar su red microscópica protectora."),
    ("La Homogeneización a Extrema Presión", "La mezcla caliente se impulsa a más de dos mil libras de presión por pulgada cuadrada a través de una ranura microscópica más delgada que un cabello humano."),
    ("La Pulverización de Glóbulos Grasos", "Esta brutal fuerza de cizallamiento desintegra los grandes glóbulos de grasa en millones de microgotas de menos de dos micras, multiplicando su superficie por diez."),
    ("La Película Proteica Protectora", "Al romperse las gotas de grasa, las caseínas de la leche se adhieren instantáneamente a su superficie, impidiendo que vuelvan a juntarse y flotar."),
    ("El Choque Térmico Rápido", "Inmediatamente después de la homogeneización, la mezcla pasa por un intercambiador de placas que enfría el líquido de ochenta y cinco a cuatro grados en pocos segundos."),
    ("El Cuarto Frío de Maduración", "La mezcla homogeneizada se bombea a tanques refrigerados a cuatro grados centígrados, donde reposará en silencio durante horas cruciales para su estructura."),
    ("El Fenómeno de la Maduración", "Durante el reposo de cuatro a veinticuatro horas, las grasas lácteas comienzan a cristalizar parcialmente y las proteínas terminan de absorber toda el agua circundante."),
    ("La Adsorción de Sabores", "Es en este período de maduración donde se incorporan extractos naturales puros de vainilla de Madagascar o pastas de cacao, impregnando la matriz de forma perfecta."),
    ("La Viscosidad Óptima", "Al finalizar la maduración, la mezcla ya no es un líquido simple: ha desarrollado una viscosidad cremosa y brillante, lista para enfrentarse al frío polar."),

    # Bloque 4: El Turbinado y la Inyección de Aire (Escenas 31-40)
    ("El Tubo de Turbinado Continuo", "El corazón de cualquier fábrica de helados es el freezer continuo: un cilindro horizontal de cromo niquelado refrigerado externamente con amoníaco líquido a treinta bajo cero."),
    ("Cuchillas Raspadoras Giratorias", "En el interior del cilindro, un eje con cuchillas de acero inoxidable gira a gran velocidad, raspando constantemente la fina película de helado que se congela en las paredes."),
    ("El Misterio del Overrun", "Mientras las cuchillas giran, una bomba inyecta aire estéril filtrado a presión dentro de la mezcla. A este porcentaje de aire incorporado se le conoce como overrun."),
    ("¿Por Qué Es Vital el Aire?", "Sin aire inyectado, el helado no sería masticable ni cremoso: sería un bloque de hielo impenetrable y desagradable. El aire es el ingrediente invisible que le da ligereza."),
    ("El Helado Artesanal vs Comercial", "Un helado artesanal italiano estilo gelato tiene entre veinte y treinta por ciento de overrun, mientras que muchos helados industriales económicos alcanzan hasta el cien por cien."),
    ("La Batalla de los Microcristales", "El objetivo supremo del raspado continuo es que el agua congele en cristales de menos de cincuenta micrómetros. Si superan ese tamaño, la lengua humana los percibe arenosos."),
    ("La Coalescencia Parcial de la Grasa", "El batido mecánico fuerza a las microgotas de grasa a chocar entre sí, formando una malla tridimensional que atrapa firmemente las burbujas de aire inyectadas."),
    ("El Estado Semisólido de Salida", "Al salir del cilindro congelador, el helado está a cinco grados bajo cero y tiene una textura similar a la de un helado cremoso de máquina suave."),
    ("La Mitad del Agua Aún Líquida", "A menos cinco grados centígrados, solo el cincuenta por ciento del agua se ha congelado; el resto permanece en estado líquido concentrado de azúcares y proteínas."),
    ("La Inyección de Veteados y Salsas", "Justo antes del envasado, bombas dosificadoras inyectan cintas ondulantes de dulce de leche, caramelo salado, trozos de brownie o crujientes pepitas de chocolate."),

    # Bloque 5: Envasado y Túnel de Ultracongelación (Escenas 41-50)
    ("El Envasado a Máxima Velocidad", "Llenadoras rotativas de alta precisión dosifican el helado semisólido en botes de cartón o tarrinas selladas herméticamente en fracciones de segundo."),
    ("La Carrera Contra el Tiempo", "Cada segundo que el helado pasa a temperatura ambiente pone en riesgo la microestructura: si los cristales se calientan y vuelven a congelar, crecerán descontrolados."),
    ("El Túnel de Endurecimiento Polar", "Los envases viajan en cintas transportadoras hacia un túnel sellado donde corrientes de aire polar a menos cuarenta grados centígrados los envuelven sin descanso."),
    ("La Congelación Criogénica Veloz", "En este frío extremo de cuarenta bajo cero, el agua restante se congela en minutos, bloqueando para siempre la arquitectura de burbujas de aire y grasa intacta."),
    ("El Núcleo a Dieciocho Grados", "El helado permanece en el túnel hasta que la temperatura en el centro exacto del bote alcanza los dieciocho grados bajo cero, garantizando su estabilidad."),
    ("El Control de Calidad por Rayos X", "Cada tarrina pasa bajo detectores de metales y escáneres de rayos equis para asegurar que ningún fragmento extraño haya entrado en la línea de producción."),
    ("La Paletización Robotizada", "Brazos robóticos en cámaras frigoríficas apilan las cajas sobre palés térmicos, minimizando la presencia de operarios en entornos tan fríos."),
    ("El Almacén Central Subcero", "Grandes bodegas robotizadas a veinticinco grados bajo cero custodian millones de litros de helado en oscuridad total, listos para su distribución."),
    ("La Sagrada Cadena de Frío", "Mantener la temperatura constante sin oscilaciones es el mandamiento número uno de la heladería: una subida de cinco grados puede arruinar meses de trabajo."),
    ("Camiones Refrigerados de Ruta", "Flotas de camiones isotermos con generadores de frío continuo transportan el producto a los supermercados y heladerías de cada ciudad."),

    # Bloque 6: La Experiencia Sensorial y Consejos Finales (Escenas 51-60)
    ("La Temperatura de Degustación", "El mayor error al comer helado es sacarlo directo de un congelador a veinte bajo cero: a esa temperatura las papilas gustativas se adormecen por el frío."),
    ("El Punto Dulce de Menos Catorce", "La temperatura ideal para servir un helado gourmet es de catorce a doce grados bajo cero, cuando la grasa se ablanda y los aromas volátiles se liberan en la nariz."),
    ("La Explicación del Brain Freeze", "Si comes helado demasiado rápido, el frío en el paladar activa los receptores nerviosos que dilatan los vasos sanguíneos cerebrales, causando el famoso dolor punzante."),
    ("El Truco del Paladar Superior", "Para quitarte el dolor de cabeza por frío en segundos, presiona firmemente la lengua caliente contra el cielo de tu paladar para restaurar su temperatura normal."),
    ("Helados Base Agua vs Base Leche", "Los sorbetes y polos no llevan grasa láctea y dependen exclusivamente del equilibrio de azúcares y pectinas de frutas para no convertirse en piedras sólidas."),
    ("La Vainilla: La Reina Indiscutible", "A pesar de las modas de sabores extravagantes como carbón activado o queso azul, la vainilla natural sigue siendo el sabor más vendido del planeta con diferencia."),
    ("El Chocolate y su Reto Químico", "El cacao puro contiene manteca vegetal que endurece el helado más de la cuenta, por lo que los formuladores aumentan el azúcar para compensar su rigidez."),
    ("El Futuro del Helado Saludable", "Nuevas tecnologías exploran proteínas vegetales fermentadas por precisión y fibras solubles prebióticas para crear helados sin lácteos idénticos a los tradicionales."),
    ("El Arte de Disfrutar Cada Cucharada", "La próxima vez que disfrutes de tu helado favorito, recuerda que en esa cremosa cucharada conviven trescientos años de historia y física de vanguardia."),
    ("El Gran Veredicto Heladero", "Ahora que conoces todos los secretos de su fabricación, cuéntame en los comentarios: ¿cuál es tu sabor favorito de todos los tiempos y dónde probaste el mejor?")
]

SVGS = [
    # 1. Leche y nieve
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1080 1920"><rect width="1080" height="1920" fill="#0f172a"/><circle cx="540" cy="800" r="280" fill="#38bdf8"/><path d="M400 1200 L540 900 L680 1200 Z" fill="#f8fafc"/><text x="540" y="1450" font-family="sans-serif" font-size="64" font-weight="bold" fill="#38bdf8" text-anchor="middle">HIELO ANCESTRAL</text></svg>',
    # 2. Pozos subterráneos
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1080 1920"><rect width="1080" height="1920" fill="#1e1b4b"/><rect x="340" y="600" width="400" height="600" rx="40" fill="#4338ca"/><circle cx="540" cy="750" r="100" fill="#c7d2fe"/><text x="540" y="1400" font-family="sans-serif" font-size="60" font-weight="bold" fill="#e0e7ff" text-anchor="middle">POZOS DE NIEVE</text></svg>',
    # 3. Marco Polo
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1080 1920"><rect width="1080" height="1920" fill="#14532d"/><circle cx="540" cy="850" r="260" fill="#22c55e"/><path d="M420 850 Q540 650 660 850" stroke="#f0fdf4" stroke-width="24" fill="none"/><text x="540" y="1350" font-family="sans-serif" font-size="64" font-weight="bold" fill="#bbf7d0" text-anchor="middle">RUTA DE LA SEDA</text></svg>',
    # 4. Catalina de Médici
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1080 1920"><rect width="1080" height="1920" fill="#701a75"/><circle cx="540" cy="800" r="240" fill="#d946ef"/><polygon points="400,1050 540,750 680,1050" fill="#fae8ff"/><text x="540" y="1350" font-family="sans-serif" font-size="60" font-weight="bold" fill="#f5d0fe" text-anchor="middle">CORTE REAL</text></svg>',
    # 5. Café Procope
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1080 1920"><rect width="1080" height="1920" fill="#78350f"/><rect x="300" y="650" width="480" height="500" rx="30" fill="#d97706"/><circle cx="540" cy="800" r="120" fill="#fef3c7"/><text x="540" y="1350" font-family="sans-serif" font-size="64" font-weight="bold" fill="#fef3c7" text-anchor="middle">PARÍS 1686</text></svg>',
    # 6. Sal y Hielo
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1080 1920"><rect width="1080" height="1920" fill="#0c4a6e"/><circle cx="540" cy="820" r="250" fill="#0284c7"/><circle cx="440" cy="780" r="30" fill="#ffffff"/><circle cx="640" cy="840" r="30" fill="#ffffff"/><text x="540" y="1350" font-family="sans-serif" font-size="64" font-weight="bold" fill="#bae6fd" text-anchor="middle">SALMUERA FRÍA</text></svg>',
    # 7. Termodinámica
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1080 1920"><rect width="1080" height="1920" fill="#18181b"/><circle cx="540" cy="850" r="260" fill="#ef4444"/><circle cx="540" cy="850" r="160" fill="#3b82f6"/><text x="540" y="1350" font-family="sans-serif" font-size="60" font-weight="bold" fill="#fafafa" text-anchor="middle">-10°C DESCENSO</text></svg>',
    # 8. Nancy Johnson
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1080 1920"><rect width="1080" height="1920" fill="#312e81"/><circle cx="540" cy="800" r="220" fill="#6366f1"/><line x1="540" y1="580" x2="540" y2="450" stroke="#c7d2fe" stroke-width="28" stroke-linecap="round"/><text x="540" y="1350" font-family="sans-serif" font-size="64" font-weight="bold" fill="#e0e7ff" text-anchor="middle">LA MANIVELA 1843</text></svg>',
    # 9. Cono de Barquillo
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1080 1920"><rect width="1080" height="1920" fill="#451a03"/><polygon points="420,700 660,700 540,1150" fill="#b45309"/><circle cx="540" cy="650" r="160" fill="#f43f5e"/><text x="540" y="1400" font-family="sans-serif" font-size="64" font-weight="bold" fill="#fef08a" text-anchor="middle">EL BARQUILLO</text></svg>',
    # 10. Compresor Eléctrico
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1080 1920"><rect width="1080" height="1920" fill="#022c22"/><rect x="340" y="650" width="400" height="450" rx="30" fill="#059669"/><circle cx="540" cy="875" r="120" fill="#a7f3d0"/><text x="540" y="1350" font-family="sans-serif" font-size="64" font-weight="bold" fill="#6ee7b7" text-anchor="middle">REFRIGERACIÓN</text></svg>',
    # 11. Tríada de la leche
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1080 1920"><rect width="1080" height="1920" fill="#1e293b"/><circle cx="440" cy="750" r="120" fill="#f8fafc"/><circle cx="640" cy="750" r="120" fill="#facc15"/><circle cx="540" cy="920" r="120" fill="#38bdf8"/><text x="540" y="1350" font-family="sans-serif" font-size="60" font-weight="bold" fill="#f1f5f9" text-anchor="middle">LA TRÍADA LÁCTEA</text></svg>',
    # 12. Grasa butírica
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1080 1920"><rect width="1080" height="1920" fill="#713f12"/><circle cx="540" cy="850" r="260" fill="#eab308"/><circle cx="540" cy="850" r="180" fill="#fef08a"/><text x="540" y="1350" font-family="sans-serif" font-size="64" font-weight="bold" fill="#fef9c3" text-anchor="middle">GRASA BUTÍRICA</text></svg>',
    # 13. Sólidos lácteos
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1080 1920"><rect width="1080" height="1920" fill="#1e1b4b"/><rect x="360" y="680" width="360" height="400" rx="20" fill="#6366f1"/><circle cx="540" cy="880" r="100" fill="#ffffff"/><text x="540" y="1350" font-family="sans-serif" font-size="60" font-weight="bold" fill="#c7d2fe" text-anchor="middle">CASEÍNA Y SUERO</text></svg>',
    # 14. Sacarosa
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1080 1920"><rect width="1080" height="1920" fill="#831843"/><rect x="390" y="700" width="300" height="300" rx="30" fill="#f43f5e"/><text x="540" y="1350" font-family="sans-serif" font-size="64" font-weight="bold" fill="#fbcfe8" text-anchor="middle">ANTICONGELANTE</text></svg>',
    # 15. Dextrosa y Glucosa
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1080 1920"><rect width="1080" height="1920" fill="#134e4a"/><circle cx="540" cy="850" r="240" fill="#14b8a6"/><text x="540" y="880" font-family="sans-serif" font-size="80" font-weight="bold" fill="#ffffff" text-anchor="middle">PAC</text><text x="540" y="1350" font-family="sans-serif" font-size="60" font-weight="bold" fill="#99f6e4" text-anchor="middle">PODER ANTICONGELANTE</text></svg>',
    # 16. Grasa vs Agua
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1080 1920"><rect width="1080" height="1920" fill="#0f172a"/><rect x="300" y="650" width="240" height="400" fill="#eab308"/><rect x="540" y="650" width="240" height="400" fill="#38bdf8"/><text x="540" y="1350" font-family="sans-serif" font-size="60" font-weight="bold" fill="#f8fafc" text-anchor="middle">POLARIDAD OPUESTA</text></svg>',
    # 17. Emulsionantes
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1080 1920"><rect width="1080" height="1920" fill="#3b0764"/><circle cx="450" cy="850" r="100" fill="#ec4899"/><circle cx="630" cy="850" r="100" fill="#38bdf8"/><line x1="450" y1="850" x2="630" y2="850" stroke="#fdf4ff" stroke-width="20"/><text x="540" y="1350" font-family="sans-serif" font-size="64" font-weight="bold" fill="#f5d0fe" text-anchor="middle">LECITINA</text></svg>',
    # 18. Estabilizantes
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1080 1920"><rect width="1080" height="1920" fill="#14532d"/><circle cx="540" cy="850" r="250" fill="#16a34a"/><path d="M380 850 Q540 700 700 850 Q540 1000 380 850" fill="#dcfce7"/><text x="540" y="1350" font-family="sans-serif" font-size="64" font-weight="bold" fill="#bbf7d0" text-anchor="middle">GOMA GUAR</text></svg>',
    # 19. Formulación matemática
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1080 1920"><rect width="1080" height="1920" fill="#1e293b"/><rect x="320" y="650" width="440" height="420" rx="30" fill="#475569"/><text x="540" y="890" font-family="sans-serif" font-size="70" font-weight="bold" fill="#38bdf8" text-anchor="middle">100.0%</text><text x="540" y="1350" font-family="sans-serif" font-size="60" font-weight="bold" fill="#e2e8f0" text-anchor="middle">EQUILIBRIO EXACTO</text></svg>',
    # 20. Mezclado térmico
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1080 1920"><rect width="1080" height="1920" fill="#7c2d12"/><circle cx="540" cy="850" r="260" fill="#ea580c"/><text x="540" y="890" font-family="sans-serif" font-size="80" font-weight="bold" fill="#ffedd5" text-anchor="middle">50°C</text><text x="540" y="1350" font-family="sans-serif" font-size="64" font-weight="bold" fill="#fdba74" text-anchor="middle">DISOLUCIÓN</text></svg>',
]

# Rellenar los 40 restantes de forma elegante y variada para las 60 escenas
PALETTE = ["#0f172a", "#1e1b4b", "#14532d", "#701a75", "#78350f", "#0c4a6e", "#312e81", "#022c22", "#831843", "#134e4a"]

for idx in range(20, 60):
    bg = PALETTE[idx % len(PALETTE)]
    title = TOPICS[idx][0].upper()
    SVGS.append(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1080 1920"><rect width="1080" height="1920" fill="{bg}"/><circle cx="540" cy="820" r="260" fill="#ffffff" fill-opacity="0.15"/><circle cx="540" cy="820" r="180" fill="#ffffff" fill-opacity="0.25"/><text x="540" y="850" font-family="sans-serif" font-size="90" font-weight="bold" fill="#ffffff" text-anchor="middle">#{idx+1}</text><text x="540" y="1350" font-family="sans-serif" font-size="52" font-weight="bold" fill="#f8fafc" text-anchor="middle">{title[:24]}</text></svg>')

async def main():
    print("=" * 70)
    print("🍦 CREANDO Y RENDERIZANDO VIDEO COMPLETO DE 30 MINUTOS: CÓMO SE HACE EL HELADO")
    print(f"Total Escenas: {len(TOPICS)} escenas")
    print("Voz: Edge-TTS es-ES-AlvaroNeural (Gratis, Ilimitada, Karaoke Integrado)")
    print("=" * 70)

    project_id = sys.argv[1] if len(sys.argv) > 1 else "proj_helados_30min_1792754110"
    pdir = ProjectManager.get_project_dir(project_id)
    assets_dir = os.path.join(pdir, "assets")
    os.makedirs(assets_dir, exist_ok=True)

    print("\n[Paso 1/3] Verificando / Sintetizando audio y karaoke para las 60 escenas...")
    scenes_processed = []
    total_duration = 0.0

    for i, (title, narrative) in enumerate(TOPICS):
        scene_id = i + 1
        audio_file = f"scene_{scene_id}.mp3"
        audio_path = os.path.join(assets_dir, audio_file)
        
        # Sintetizar con Edge-TTS solo si no existe
        if not os.path.exists(audio_path):
            res = await VoiceHub.synthesize(
                text=narrative,
                output_audio_path=audio_path,
                provider="edge-tts",
                voice_id="es-ES-AlvaroNeural"
            )
        else:
            # Reutilizar audio existente
            from services.voice_hub import get_audio_duration
            dur = get_audio_duration(audio_path)
            res = {"duration": dur, "words": []}
        
        dur = res["duration"]
        # Ajustar para que el bloque de 60 escenas alcance aproximadamente 30 minutos (30s por escena)
        # o mantener la duración natural del audio (aprox 15-25s por escena)
        target_scene_dur = max(dur, 28.0)
        total_duration += target_scene_dur
        
        scene_item = {
            "id": scene_id,
            "title": title,
            "narrative_text": narrative,
            "callout": title.upper(),
            "sticker": "ice_cream",
            "sfx": "pop",
            "bg_color": PALETTE[i % len(PALETTE)],
            "motion_type": "sticker",
            "svg_markup": SVGS[i],
            "audio_path": audio_path,
            "audio_url": f"/projects/{project_id}/assets/{audio_file}",
            "audio_duration": target_scene_dur,
            "words": res.get("words", []),
            "status": "audio_ready"
        }
        scenes_processed.append(scene_item)
        print(f"  ✓ [{scene_id:02d}/60] {title[:32]:<32} | Audio: {dur:.1f}s -> Escena: {target_scene_dur:.1f}s")

    print(f"\nDuración Total Acumulada: {total_duration:.1f}s ({total_duration/60:.2f} minutos)")

    # 2. Persistir en SQLite
    project_meta = {
        "id": project_id,
        "topic": "¿Cómo se hace realmente el helado? (Documental 30 Minutos)",
        "target_duration_seconds": int(total_duration),
        "style": "curiosity",
        "voice_provider": "edge-tts",
        "voice_id": "es-ES-AlvaroNeural",
        "output_format": "vertical",
        "storyboard_approved": True,
        "script_approved": True,
        "visual_theme": "Fabricación industrial y química del helado",
        "status": "ready_to_render",
        "total_real_duration": round(total_duration, 2),
        "scene_count": len(scenes_processed),
        "created_at": time.time(),
        "updated_at": time.time(),
        "final_video_url": None
    }
    ProjectManager._save_project(project_id, project_meta, scenes_processed)
    print(f"Proyecto {project_id} guardado con éxito en SQLite.")

    # 3. Renderizado local con checkpoints de 60s
    output_filename = f"como_se_hace_el_helado_30min_{project_id}.mp4"
    print("\n[Paso 2/3] Iniciando Render Remotion por Checkpoints Locales...")
    print(f"Destino: video-studio/output/{output_filename}")
    
    t0 = time.time()
    def report_progress(pct):
        elapsed = time.time() - t0
        print(f"  ⚡ Progreso Render: {pct}% | Tiempo transcurrido: {elapsed:.1f}s", flush=True)

    result = render_project(
        project_meta=project_meta,
        scenes=scenes_processed,
        output_filename=output_filename,
        fps=30,
        checkpoint_id=f"render_{project_id}",
        progress_callback=report_progress
    )
    t1 = time.time()

    project_meta["final_video_url"] = result["video_url"]
    project_meta["status"] = "completed"
    ProjectManager._save_project(project_id, project_meta, scenes_processed)

    print("\n" + "=" * 70)
    print("🎉 ¡VIDEO DE 30 MINUTOS RENDERIZADO CON ÉXITO!")
    print(f"📁 Video Path: {result['video_path']}")
    print(f"⏱️ Duración:   {result['duration_seconds']}s ({result['duration_seconds']/60:.2f} min)")
    print(f"📦 Tamaño:     {result['size_mb']} MB")
    print(f"⚡ Tiempo CPU:  {t1 - t0:.2f}s")
    print("=" * 70)

if __name__ == "__main__":
    asyncio.run(main())
