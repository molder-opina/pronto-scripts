import shutil
from pathlib import Path

# Source Directory (Artifacts)
ARTIFACTS_DIR = Path("/Users/molder/.gemini/antigravity/brain/a04e6b23-bc24-411d-bf33-0724cf2fa329")

# Destination Directory
DEST_DIR = Path(
    "/Users/molder/projects/github - molder/pronto-app/src/static_content/assets/cafeteria-test/menu"
)
BRANDING_DIR = Path(
    "/Users/molder/projects/github - molder/pronto-app/src/static_content/assets/cafeteria-test/branding"
)

# Create dirs if not exist
DEST_DIR.mkdir(parents=True, exist_ok=True)
BRANDING_DIR.mkdir(parents=True, exist_ok=True)


# Find latest generated images
def find_latest(pattern):
    # PTH207: Replace glob with Path.glob
    files = list(ARTIFACTS_DIR.glob(pattern))
    if not files:
        return None
    # Use path.stat().st_ctime instead of os.path.getctime
    return max(files, key=lambda p: p.stat().st_ctime)


img_combo = find_latest("combo_generic_placeholder_*.png")
img_burger = find_latest("placeholder_burger_*.png")
img_pizza = find_latest("placeholder_pizza_*.png")
img_drink = find_latest("placeholder_drink_*.png")
img_logo = find_latest("pronto_logo_branding_*.png")

print(
    f"Sources Found:\nCombo: {img_combo}\nBurger: {img_burger}\nPizza: {img_pizza}\nDrink: {img_drink}\nLogo: {img_logo}"
)

# Mapping Logic
mappings = [
    ("hamburguesa_", img_burger),
    ("pizza_", img_pizza),
    ("combo_", img_combo),
    ("combos_", img_combo),
    ("alitas_", img_burger),
    ("tacos_", img_burger),
    ("camarones_", img_burger),
    ("costillas_", img_burger),
    ("molcajete", img_burger),
    ("chilaquiles_", img_burger),
    ("huevos_", img_burger),
    ("hotcakes", img_burger),
    ("molletes", img_burger),
    ("omelette", img_burger),
    ("pan_frances", img_burger),
    ("bebida_", img_drink),
    ("cerveza_", img_drink),
    ("agua_", img_drink),
    ("malteada_", img_drink),
    ("frappe_", img_drink),
    ("cappuccino", img_drink),
    ("michelada", img_drink),
    ("te_helado", img_drink),
    ("smoothie", img_drink),
    ("cheesecake_", img_drink),
    ("brownie_", img_drink),
    ("tiramisu", img_drink),
    ("helado", img_drink),
    ("flan", img_drink),
    ("pastel_", img_drink),
    ("churros", img_drink),
]

target_filenames = [
    "hamburguesa_clasica.png",
    "hamburguesa_bbq.png",
    "hamburguesa_veggie.png",
    "hamburguesa_mexicana.png",
    "hamburguesa_pollo.png",
    "hamburguesa_blue.png",
    "pizza_margherita.png",
    "pizza_pepperoni.png",
    "pizza_cuatro_quesos.png",
    "pizza_hawaiana.png",
    "pizza_vegetariana.png",
    "combo_familiar.png",
    "combo_pareja.png",
    "combo_individual.png",
    "combos_familiar.png",
    "combo_pizza.png",
    "combo_tacos.png",
    "combo_ensalada.png",
    "alitas_bbq.png",
    "alitas_buffalo.png",
    "te_helado.png",
    "smoothie.png",
    "cerveza_nacional.png",
    "agua_horchata.png",
    "agua_jamaica.png",
    "agua_tamarindo.png",
    "malteada_chocolate.png",
    "malteada_fresa.png",
    "malteada_vainilla.png",
    "frappe_cafe.png",
    "cappuccino.png",
    "michelada.png",
    "cheesecake_rojo.png",
    "brownie_helado.png",
    "tiramisu.png",
    "helado.png",
    "flan.png",
    "pastel_chocolate.png",
    "churros.png",
    "chilaquiles_rojos.png",
    "chilaquiles_verdes.png",
    "huevos_rancheros.png",
    "huevos_jamon.png",
    "hotcakes.png",
    "molletes.png",
    "omelette.png",
    "pan_frances.png",
    "camarones_ajillo.png",
    "molcajete.png",
    "costillas_bbq.png",
]

count = 0
for target in target_filenames:
    src = None
    for prefix, source_img in mappings:
        if target.startswith(prefix) or prefix in target:
            src = source_img
            break

    if src:
        # Use / operator for Path joining
        dest_path = DEST_DIR / target
        shutil.copy2(src, dest_path)
        print(f"✅ Created {target}")
        count += 1
    else:
        print(f"⚠️ No mapping for {target}")

# Logo
if img_logo:
    shutil.copy2(img_logo, BRANDING_DIR / "logo.png")
    print("✅ Created logo.png")

print(f"Total Assets Populated: {count}")
