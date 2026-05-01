const DEFAULT_DATA_PATH  = "../logs/CronometerMonitorResult.json";
const HISTORY_CSV_PATH   = "../logs/CronometerHistory.csv";

const NUTRITION_SCHEMA = {
    calories:      { unit: "kcal", fda: { reference: 2000 },    bariatric: { range: [1800, 2200] }, keto: { range: [1600, 2000] } },
    protein:       { unit: "g",    fda: { dailyValue: 50 },      bariatric: { min: 60, optimal: 90 }, keto: { range: [100, 150] } },
    carbohydrates: { unit: "g",    fda: { dailyValue: 275 },     bariatric: { note: "Individualized" }, keto: { max: 50 } },
    fiber:         { unit: "g",    fda: { dailyValue: 28 },                                            keto: { min: 25 } },
    fat:           { unit: "g",    fda: { dailyValue: 78 },                                            keto: { min: 130 } },
    omega3:        { unit: "g",    fda: { target: 1.6 },        bariatric: { target: 1.6 },           keto: { min: 1.6 } },
    ala:           { unit: "g",    fda: { target: 1.6 },        bariatric: { target: 1.6 },           keto: { min: 1.6 } },
    dha:           { unit: "g",    fda: { target: 0.25 },       bariatric: { target: 0.25 },          keto: { min: 0.25 } },
    epa:           { unit: "g",    fda: { target: 0.25 },       bariatric: { target: 0.25 },          keto: { min: 0.25 } },
    omega6:        { unit: "g",    fda: { target: 17 },         bariatric: { target: 17 },            keto: { min: 17 } },
    la:            { unit: "g",    fda: { target: 17 },         bariatric: { target: 17 },            keto: { min: 17 } },
    saturatedFat:  { unit: "g",    fda: { max: 20 },                                                   keto: { max: 40 } },
    transFat:      { unit: "g",    fda: { note: "Minimize" },                                          keto: { note: "Minimize" } },
    cholesterol:   { unit: "mg",   fda: { max: 300 },                                                  keto: { note: "Not restricted on keto" } },
    sodium:        { unit: "mg",   fda: { max: 2300 },                                                 keto: { range: [2000, 4000] } },
    potassium:     { unit: "mg",   fda: { dailyValue: 4700 },                                          keto: { min: 3500 } },
    magnesium:     { unit: "mg",   fda: { dailyValue: 420 },                                           keto: { range: [300, 500] } },
    phosphorus:    { unit: "mg",   fda: { dailyValue: 1250 },    bariatric: { target: 1250 },         keto: { min: 1250 } },
    manganese:     { unit: "mg",   fda: { dailyValue: 2.3 },     bariatric: { target: 2.3 },          keto: { min: 2.3 } },
    selenium:      { unit: "mcg",  fda: { dailyValue: 55 },      bariatric: { target: 55 },           keto: { min: 55 } },
    addedSugars:   { unit: "g",    fda: { max: 50 },                                                   keto: { max: 5 } },
    vitaminA:      { unit: "mcg",  fda: { dailyValue: 900 },     bariatric: { range: [1500, 3000] } },
    vitaminC:      { unit: "mg",   fda: { dailyValue: 90 },      bariatric: { target: 90 },           keto: { min: 90 } },
    vitaminD:      { unit: "mcg",  fda: { dailyValue: 20 },      bariatric: { target: 75 } },
    vitaminE:      { unit: "mg",   fda: { dailyValue: 15 },      bariatric: { target: 15 },           keto: { min: 15 } },
    vitaminK:      { unit: "mcg",  fda: { dailyValue: 120 },     bariatric: { target: 120 },          keto: { min: 120 } },
    vitaminB12:    { unit: "mcg",  fda: { dailyValue: 2.4 },     bariatric: { range: [350, 1000] } },
    iron:          { unit: "mg",   fda: { dailyValue: 18 },      bariatric: { range: [45, 60] } },
    calcium:       { unit: "mg",   fda: { dailyValue: 1300 },    bariatric: { range: [1200, 1500] } },
    thiaminB1:     { unit: "mg",   fda: { dailyValue: 1.2 },     bariatric: { min: 12 } },
    riboflavinB2:  { unit: "mg",   fda: { dailyValue: 1.3 },     bariatric: { target: 1.3 },          keto: { min: 1.3 } },
    niacinB3:      { unit: "mg",   fda: { dailyValue: 16 },      bariatric: { target: 16 },           keto: { min: 16 } },
    pantothenicAcidB5: { unit: "mg", fda: { dailyValue: 5 },     bariatric: { target: 5 },            keto: { min: 5 } },
    pyridoxineB6:  { unit: "mg",   fda: { dailyValue: 1.7 },     bariatric: { target: 1.7 },          keto: { min: 1.7 } },
    folate:        { unit: "mcg",  fda: { dailyValue: 400 },     bariatric: { range: [400, 800] } },
    zinc:          { unit: "mg",   fda: { dailyValue: 11 },      bariatric: { range: [8, 22] } },
    copper:        { unit: "mg",   fda: { dailyValue: 0.9 },     bariatric: { range: [1, 2] } }
};

const FOOD_RECOMMENDATIONS = {
    standard: {
        "Protein":         "Chicken breast, eggs, Greek yogurt, cottage cheese, tuna, whey protein",
        "Carbs":           "Oats, sweet potato, rice, banana, whole grain bread",
        "Fat":             "Avocado, nuts, salmon, olive oil, seeds",
        "Omega-3":         "Salmon, sardines, trout, flaxseed, chia seeds, walnuts",
        "ALA":             "Flaxseed, chia seeds, walnuts, hemp seeds, canola oil",
        "DHA":             "Salmon, sardines, trout, algae oil, fish oil",
        "EPA":             "Salmon, sardines, mackerel, trout, fish oil",
        "Omega-6":         "Sunflower seeds, pumpkin seeds, walnuts, tofu, plant oils",
        "LA":              "Sunflower seeds, pumpkin seeds, walnuts, tofu, plant oils",
        "Fiber":           "Beans, lentils, oats, chia seeds, broccoli, apples",
        "Calcium":         "Milk, yogurt, cheese, kale, fortified plant milk, sardines",
        "Potassium":       "Banana, sweet potato, spinach, avocado, salmon",
        "Magnesium":       "Pumpkin seeds, spinach, almonds, dark chocolate, black beans",
        "Phosphorus":      "Greek yogurt, chicken, salmon, lentils, pumpkin seeds",
        "Manganese":       "Oats, pecans, mussels, brown rice, spinach",
        "Selenium":        "Brazil nuts, tuna, eggs, sardines, turkey",
        "Iron":            "Beef, spinach, lentils, pumpkin seeds, fortified cereal, tofu",
        "Zinc":            "Beef, oysters, pumpkin seeds, hemp seeds, legumes",
        "Copper":          "Shellfish, liver, cashews, sunflower seeds, dark chocolate",
        "Vitamin A":       "Sweet potato, carrots, spinach, kale, eggs",
        "Vitamin C":       "Citrus, strawberries, kiwi, bell peppers, broccoli",
        "Vitamin D":       "Salmon, tuna, fortified milk, egg yolks, mushrooms",
        "Vitamin E":       "Sunflower seeds, almonds, hazelnuts, avocado, spinach",
        "Vitamin K":       "Spinach, kale, broccoli, Brussels sprouts, romaine",
        "B1 (Thiamine)":   "Pork, whole grains, legumes, sunflower seeds, nutritional yeast",
        "B2 (Riboflavin)": "Milk, eggs, almonds, beef, mushrooms",
        "B3 (Niacin)":     "Chicken, tuna, turkey, peanuts, brown rice",
        "B5 (Pantothenic Acid)": "Chicken, mushrooms, avocado, yogurt, sunflower seeds",
        "B6 (Pyridoxine)": "Salmon, chicken, potatoes, bananas, chickpeas",
        "B12 (Cobalamin)": "Beef, salmon, eggs, dairy, fortified cereals",
        "Folate":          "Leafy greens, lentils, asparagus, avocado, eggs"
    },
    bariatric: {
        "Protein":         "Chicken breast, eggs, Greek yogurt, cottage cheese, tuna, whey protein shake",
        "Fat":             "Avocado, nuts, olive oil, salmon, nut butter",
        "Omega-3":         "Salmon, sardines, trout, flaxseed, chia seeds, fish oil",
        "ALA":             "Flaxseed, chia seeds, walnuts, hemp seeds",
        "DHA":             "Salmon, sardines, trout, algae oil, fish oil",
        "EPA":             "Salmon, sardines, mackerel, fish oil",
        "Omega-6":         "Sunflower seeds, walnuts, tofu, pumpkin seeds",
        "LA":              "Sunflower seeds, walnuts, tofu, pumpkin seeds",
        "Fiber":           "Broccoli, chia seeds, flaxseed, leafy greens, berries",
        "Calcium":         "Calcium citrate supplement, yogurt, cheese, fortified plant milk",
        "Potassium":       "Avocado, spinach, salmon, mushrooms, zucchini",
        "Magnesium":       "Pumpkin seeds, almonds, spinach, dark chocolate (85%+)",
        "Phosphorus":      "Greek yogurt, chicken, salmon, lentils, pumpkin seeds",
        "Manganese":       "Oats, pecans, mussels, spinach, brown rice",
        "Selenium":        "Brazil nuts, tuna, eggs, sardines, turkey",
        "Iron":            "Beef, chicken liver, spinach, lentils, pumpkin seeds",
        "Zinc":            "Beef, oysters, pumpkin seeds, hemp seeds",
        "Copper":          "Shellfish, liver, cashews, sunflower seeds",
        "Vitamin A":       "Sweet potato, carrots, spinach, eggs",
        "Vitamin C":       "Bell peppers, citrus, strawberries, broccoli, supplement",
        "Vitamin D":       "Salmon, tuna, egg yolks, fortified milk, supplement",
        "Vitamin E":       "Sunflower seeds, almonds, hazelnuts, spinach",
        "Vitamin K":       "Spinach, kale, broccoli, romaine",
        "B1 (Thiamine)":   "Pork, nutritional yeast, sunflower seeds, supplement",
        "B2 (Riboflavin)": "Milk, eggs, Greek yogurt, almonds",
        "B3 (Niacin)":     "Chicken, tuna, turkey, peanuts",
        "B5 (Pantothenic Acid)": "Chicken, yogurt, mushrooms, avocado",
        "B6 (Pyridoxine)": "Salmon, chicken, tuna, bananas",
        "B12 (Cobalamin)": "Beef, salmon, eggs, sublingual B12 supplement",
        "Folate":          "Leafy greens, asparagus, avocado, supplement"
    },
    keto: {
        "Protein":         "Beef, chicken thighs, eggs, bacon, salmon, canned tuna",
        "Fat":             "Avocado, butter, coconut oil, olive oil, heavy cream, almonds",
        "Omega-3":         "Salmon, sardines, trout, chia seeds, flaxseed, fish oil",
        "ALA":             "Flaxseed, chia seeds, walnuts, hemp seeds",
        "DHA":             "Salmon, sardines, trout, algae oil, fish oil",
        "EPA":             "Salmon, sardines, mackerel, fish oil",
        "Omega-6":         "Walnuts, sunflower seeds, pumpkin seeds, eggs",
        "LA":              "Walnuts, sunflower seeds, pumpkin seeds, eggs",
        "Fiber":           "Chia seeds, flaxseed, broccoli, cauliflower, leafy greens",
        "Sodium":          "Bone broth, pickles, olives, salt food adequately",
        "Potassium":       "Avocado, leafy greens, salmon, mushrooms, zucchini",
        "Magnesium":       "Pumpkin seeds, almonds, dark chocolate (85%+), leafy greens",
        "Phosphorus":      "Salmon, chicken, eggs, cheese, pumpkin seeds",
        "Manganese":       "Pecans, macadamia nuts, spinach, mussels, flaxseed",
        "Selenium":        "Brazil nuts, tuna, sardines, eggs, chicken",
        "Calcium":         "Cheese, sardines, leafy greens, cream",
        "Iron":            "Beef, chicken liver, bacon, spinach, pumpkin seeds",
        "Zinc":            "Beef, oysters, pumpkin seeds, hemp seeds",
        "Copper":          "Shellfish, liver, cashews, dark chocolate (85%+)",
        "Vitamin A":       "Eggs, butter, liver, leafy greens",
        "Vitamin C":       "Bell peppers, broccoli, Brussels sprouts, cauliflower, lemon",
        "Vitamin D":       "Salmon, mackerel, egg yolks, sardines",
        "Vitamin E":       "Sunflower seeds, almonds, avocado, spinach",
        "Vitamin K":       "Spinach, kale, broccoli, romaine, cabbage",
        "B1 (Thiamine)":   "Pork, sunflower seeds, macadamia nuts",
        "B2 (Riboflavin)": "Eggs, beef, almonds, mushrooms",
        "B3 (Niacin)":     "Chicken, tuna, turkey, beef",
        "B5 (Pantothenic Acid)": "Chicken, eggs, mushrooms, avocado",
        "B6 (Pyridoxine)": "Salmon, chicken, beef, avocado",
        "B12 (Cobalamin)": "Beef, salmon, sardines, eggs",
        "Folate":          "Leafy greens, asparagus, avocado, broccoli"
    }
};

const NUTRIENT_SCHEMA_MAP = {
    "Energy":          { key: "calories",      unitMatch: true },
    "Protein":         { key: "protein",       unitMatch: true },
    "Carbs":           { key: "carbohydrates", unitMatch: true },
    "Fat":             { key: "fat",           unitMatch: true },
    "Omega-3":         { key: "omega3",        unitMatch: true },
    "ALA":             { key: "ala",           unitMatch: true },
    "DHA":             { key: "dha",           unitMatch: true },
    "EPA":             { key: "epa",           unitMatch: true },
    "Omega-6":         { key: "omega6",        unitMatch: true },
    "LA":              { key: "la",            unitMatch: true },
    "Fiber":           { key: "fiber",         unitMatch: true },
    "Added Sugars":    { key: "addedSugars",   unitMatch: true },
    "Saturated":       { key: "saturatedFat",  unitMatch: true },
    "Trans-Fats":      { key: "transFat",      unitMatch: true },
    "Cholesterol":     { key: "cholesterol",   unitMatch: true },
    "Sodium":          { key: "sodium",        unitMatch: true },
    "Potassium":       { key: "potassium",     unitMatch: true },
    "Magnesium":       { key: "magnesium",     unitMatch: true },
    "Phosphorus":      { key: "phosphorus",    unitMatch: true },
    "Manganese":       { key: "manganese",     unitMatch: true },
    "Selenium":        { key: "selenium",      unitMatch: true },
    "Calcium":         { key: "calcium",       unitMatch: true },
    "Iron":            { key: "iron",          unitMatch: true },
    "Zinc":            { key: "zinc",          unitMatch: true },
    "Copper":          { key: "copper",        unitMatch: true },
    "Vitamin A":       { key: "vitaminA",      unitMatch: true },
    "Vitamin C":       { key: "vitaminC",      unitMatch: true },
    "Vitamin D":       { key: "vitaminD",      unitMatch: true, conversion: "iuToMcg" },
    "Vitamin E":       { key: "vitaminE",      unitMatch: true },
    "Vitamin K":       { key: "vitaminK",      unitMatch: true },
    "B1 (Thiamine)":   { key: "thiaminB1",     unitMatch: true },
    "B2 (Riboflavin)": { key: "riboflavinB2",  unitMatch: true },
    "B3 (Niacin)":     { key: "niacinB3",      unitMatch: true },
    "B5 (Pantothenic Acid)": { key: "pantothenicAcidB5", unitMatch: true },
    "B6 (Pyridoxine)": { key: "pyridoxineB6",  unitMatch: true },
    "B12 (Cobalamin)": { key: "vitaminB12",    unitMatch: true },
    "Folate":          { key: "folate",        unitMatch: true }
};

const knownTopLevelFields = new Set([
    "SchemaVersion",
    "DiaryDate",
    "CaloriesConsumed",
    "CaloriesRemaining",
    "CalorieGoal",
    "ProteinGrams",
    "ProteinRemainingGrams",
    "ProteinGoalGrams",
    "CarbsGrams",
    "NetCarbsGrams",
    "CarbsRemainingGrams",
    "CarbohydrateGoalGrams",
    "FatGrams",
    "FatRemainingGrams",
    "FatGoalGrams",
    "FiberGrams",
    "SugarsGrams",
    "AddedSugarsGrams",
    "SaturatedFatGrams",
    "TransFatGrams",
    "CholesterolMg",
    "SodiumMg",
    "PotassiumMg",
    "WaterG",
    "CalciumMg",
    "IronMg",
    "MagnesiumMg",
    "PhosphorusMg",
    "ZincMg",
    "CopperMg",
    "ManganeseMg",
    "SeleniumUg",
    "VitaminA_ug",
    "VitaminC_mg",
    "VitaminD_IU",
    "VitaminE_mg",
    "VitaminK_ug",
    "B1_Thiamine_mg",
    "B2_Riboflavin_mg",
    "B3_Niacin_mg",
    "B5_PantothenicAcid_mg",
    "B6_Pyridoxine_mg",
    "B12_Cobalamin_ug",
    "Folate_ug",
    "QueryStatus",
    "ValidationStatus",
    "RequiredFieldsPresent",
    "MissingRequiredFields",
    "MissingRequiredSummary",
    "Nutrients",
    "Alerts",
    "ExtractionMethod",
    "ExtractionAttemptsUsed",
    "DateSelectorUsed",
    "TablesSelectorUsed",
    "NutrientNameSelectorUsed",
    "NutrientValueSelectorUsed",
    "NutrientUnitSelectorUsed",
    "MissingSignalsSummary",
    "OutputMetadata"
]);

const state = {
    data: null,
    sourceLabel: "Waiting for data",
    sourceKind: "none",
    targetMode: "standard",
    historyRows: [],
    historyDays: 7
};

const elements = {
    sourceLabel: document.getElementById("sourceLabel"),
    statusText: document.getElementById("statusText"),
    heroMetrics: document.getElementById("heroMetrics"),
    macroCards: document.getElementById("macroCards"),
    alertsList: document.getElementById("alertsList"),
    statusDetails: document.getElementById("statusDetails"),
    nutrientTableBody: document.getElementById("nutrientTableBody"),
    nutrientSearch: document.getElementById("nutrientSearch"),
    targetModeSelect: document.getElementById("targetModeSelect"),
    futureSections: document.getElementById("futureSections"),
    fileInput: document.getElementById("fileInput"),
    reloadDefaultButton: document.getElementById("reloadDefaultButton"),
    dropZone: document.getElementById("dropZone"),
    emptyStateTemplate: document.getElementById("emptyStateTemplate"),
    historyChart: document.getElementById("historyChart"),
    dayToggleBtns: document.querySelectorAll(".toggle-btn[data-days]")
};

function formatNumber(value, maximumFractionDigits = 1) {
    if (typeof value !== "number" || Number.isNaN(value)) {
        return "n/a";
    }

    return new Intl.NumberFormat(undefined, {
        maximumFractionDigits
    }).format(value);
}

function formatValue(value) {
    if (value === null || value === undefined || value === "") {
        return "n/a";
    }

    if (typeof value === "number") {
        return formatNumber(value);
    }

    if (typeof value === "boolean") {
        return value ? "Yes" : "No";
    }

    if (Array.isArray(value)) {
        return value.length ? value.join(", ") : "None";
    }

    if (typeof value === "object") {
        return JSON.stringify(value, null, 2);
    }

    return String(value);
}

function cloneEmptyState() {
    return elements.emptyStateTemplate.content.firstElementChild.cloneNode(true);
}

function setStatus(message, tone = "neutral") {
    elements.statusText.textContent = message;
    elements.statusText.dataset.tone = tone;
}

function createMetricCard(label, value, subvalue) {
    const card = document.createElement("article");
    card.className = "metric-card";
    card.innerHTML = `
        <div class="label">${label}</div>
        <div class="value">${value}</div>
        <div class="subvalue">${subvalue}</div>
    `;
    return card;
}

function createMacroCard(label, consumed, goal, remaining, unit) {
    const percent = goal > 0 ? Math.max(0, Math.min((consumed / goal) * 100, 100)) : 0;
    const card = document.createElement("article");
    card.className = "macro-card";
    card.innerHTML = `
        <div class="label">${label}</div>
        <div class="value">${formatNumber(consumed)} <span class="muted">${unit}</span></div>
        <div class="subvalue">Goal ${formatNumber(goal)} ${unit}. Remaining ${formatNumber(remaining)} ${unit}</div>
        <div class="progress-shell">
            <div class="progress-bar" style="width: ${percent}%"></div>
        </div>
    `;
    return card;
}

function renderHeroMetrics(data) {
    const metrics = [
        ["Diary Date", formatValue(data.DiaryDate), `Schema ${formatValue(data.SchemaVersion)}`],
        ["Calories", `${formatNumber(data.CaloriesConsumed)} kcal`, `${formatNumber(data.CaloriesRemaining)} kcal remaining`],
        ["Protein", `${formatNumber(data.ProteinGrams)} g`, `${formatNumber(data.ProteinRemainingGrams)} g remaining`],
        ["Validation", formatValue(data.ValidationStatus), `Query ${formatValue(data.QueryStatus)}`]
    ];

    elements.heroMetrics.replaceChildren(...metrics.map(([label, value, subvalue]) => createMetricCard(label, value, subvalue)));
}

function renderMacroCards(data) {
    const cards = [
        createMacroCard("Calories", data.CaloriesConsumed, data.CalorieGoal, data.CaloriesRemaining, "kcal"),
        createMacroCard("Protein", data.ProteinGrams, data.ProteinGoalGrams, data.ProteinRemainingGrams, "g"),
        createMacroCard("Carbs", data.CarbsGrams, data.CarbohydrateGoalGrams, data.CarbsRemainingGrams, "g"),
        createMacroCard("Fat", data.FatGrams, data.FatGoalGrams, data.FatRemainingGrams, "g")
    ];

    elements.macroCards.replaceChildren(...cards);
}

function renderAlerts(data) {
    const alerts = Array.isArray(data.Alerts) ? data.Alerts : [];
    if (!alerts.length) {
        elements.alertsList.replaceChildren(cloneEmptyState());
        return;
    }

    const items = alerts.map((alertText) => {
        const div = document.createElement("div");
        div.className = "alert-item";
        div.textContent = alertText;
        return div;
    });

    elements.alertsList.replaceChildren(...items);
}

function renderStatusDetails(data) {
    const details = [
        ["Extraction Method", data.ExtractionMethod],
        ["Attempts Used", data.ExtractionAttemptsUsed],
        ["Required Fields Present", data.RequiredFieldsPresent],
        ["Missing Required Summary", data.MissingRequiredSummary],
        ["Missing Signals Summary", data.MissingSignalsSummary],
        ["Date Selector", data.DateSelectorUsed],
        ["Tables Selector", data.TablesSelectorUsed],
        ["Value Selector", data.NutrientValueSelectorUsed]
    ];

    const nodes = details.map(([label, value]) => {
        const wrapper = document.createElement("div");
        wrapper.className = "detail-row";

        const dt = document.createElement("dt");
        dt.textContent = label;

        const dd = document.createElement("dd");
        dd.textContent = formatValue(value);

        wrapper.append(dt, dd);
        return wrapper;
    });

    elements.statusDetails.replaceChildren(...nodes);
}

function resolveTargetEntry(entry, unit, unitMatch) {
    if (!entry) return null;
    if (entry.range)        return { type: "range",  min: entry.range[0], max: entry.range[1], display: `${entry.range[0]}–${entry.range[1]} ${unit}`, unitMatch };
    if (entry.target != null)  return { type: "target", value: entry.target,  display: `${entry.target} ${unit}`,  unitMatch };
    if (entry.optimal != null) return { type: "target", value: entry.optimal, display: `${entry.optimal} ${unit}`, unitMatch };
    if (entry.min != null)     return { type: "min",    value: entry.min,     display: `≥ ${entry.min} ${unit}`,   unitMatch };
    if (entry.max != null)     return { type: "max",    value: entry.max,     display: `≤ ${entry.max} ${unit}`,   unitMatch };
    if (entry.dailyValue != null) return { type: "target", value: entry.dailyValue, display: `${entry.dailyValue} ${unit}`, unitMatch };
    if (entry.reference != null)  return { type: "target", value: entry.reference,  display: `${entry.reference} ${unit}`,  unitMatch };
    if (entry.note)            return { type: "note", display: entry.note, unitMatch };
    return null;
}

function getTarget(nutrientName, mode) {
    const mapping = NUTRIENT_SCHEMA_MAP[nutrientName];
    if (!mapping) return null;
    const schema = NUTRITION_SCHEMA[mapping.key];
    if (!schema) return null;

    const { unit } = schema;
    const um = mapping.unitMatch;

    if (mode === "bariatric" && schema.bariatric) return resolveTargetEntry(schema.bariatric, unit, um) ?? resolveTargetEntry(schema.fda, unit, um);
    if (mode === "keto"      && schema.keto)      return resolveTargetEntry(schema.keto,      unit, um) ?? resolveTargetEntry(schema.fda, unit, um);

    return resolveTargetEntry(schema.fda, unit, um);
}

function convertNutrientValue(value, mapping) {
    const numericValue = parseFloat(value);
    if (Number.isNaN(numericValue)) {
        return null;
    }

    if (!mapping || !mapping.conversion) {
        return numericValue;
    }

    if (mapping.conversion === "iuToMcg") {
        return numericValue / 40;
    }

    return numericValue;
}

function getStatus(value, target) {
    if (!target || !target.unitMatch || target.type === "note") return null;
    const mapping = NUTRIENT_SCHEMA_MAP[target.nutrientName];
    const v = convertNutrientValue(value, mapping);
    if (v === null) return null;

    if (target.type === "max")    return v <= target.value ? "ok" : "high";
    if (target.type === "range")  return v < target.min ? "low" : v > target.max ? "high" : "ok";
    if (target.type === "target" || target.type === "min") return v >= target.value ? "ok" : "low";
    return null;
}

function getRecommendation(nutrientName, status, mode) {
    if (status !== "low") return "";
    const map = FOOD_RECOMMENDATIONS[mode] || FOOD_RECOMMENDATIONS.standard;
    return map[nutrientName] || FOOD_RECOMMENDATIONS.standard[nutrientName] || "";
}

function renderNutrients(data) {
    const filter = elements.nutrientSearch.value.trim().toLowerCase();
    const mode = state.targetMode;
    const nutrients = Array.isArray(data.Nutrients) ? data.Nutrients : [];
    const filtered = nutrients.filter((item) => {
        const haystack = `${item.Name ?? ""} ${item.Unit ?? ""}`.toLowerCase();
        return !filter || haystack.includes(filter);
    });

    if (!filtered.length) {
        const row = document.createElement("tr");
        row.innerHTML = `<td colspan="6">No nutrient rows match the current filter.</td>`;
        elements.nutrientTableBody.replaceChildren(row);
        return;
    }

    const rows = filtered.map((nutrient) => {
        const target         = getTarget(nutrient.Name, mode);
        if (target) {
            target.nutrientName = nutrient.Name;
        }
        const status         = getStatus(nutrient.Value, target);
        const recommendation = getRecommendation(nutrient.Name, status, mode);
        const targetDisplay  = target ? target.display : "";
        const statusHtml     = status ? `<span class="status-badge status-${status}">${status}</span>` : "";
        const row = document.createElement("tr");
        row.innerHTML = `
            <td>${formatValue(nutrient.Name)}</td>
            <td>${formatValue(nutrient.Value)}</td>
            <td>${formatValue(nutrient.Unit)}</td>
            <td class="muted">${targetDisplay}</td>
            <td>${statusHtml}</td>
            <td class="recommendation-cell">${recommendation}</td>
        `;
        return row;
    });

    elements.nutrientTableBody.replaceChildren(...rows);
}

function renderObjectCard(title, value) {
    const card = document.createElement("article");
    card.className = "future-card";

    const heading = document.createElement("h3");
    heading.textContent = title;
    card.appendChild(heading);

    if (Array.isArray(value)) {
        if (!value.length) {
            card.appendChild(cloneEmptyState());
            return card;
        }

        if (typeof value[0] === "string" || typeof value[0] === "number") {
            const pillList = document.createElement("div");
            pillList.className = "pill-list";
            value.forEach((item) => {
                const pill = document.createElement("span");
                pill.className = "pill";
                pill.textContent = formatValue(item);
                pillList.appendChild(pill);
            });
            card.appendChild(pillList);
            return card;
        }
    }

    const pre = document.createElement("pre");
    pre.textContent = JSON.stringify(value, null, 2);
    card.appendChild(pre);
    return card;
}

function renderFutureSections(data) {
    const extraEntries = Object.entries(data).filter(([key]) => !knownTopLevelFields.has(key));

    if (!extraEntries.length) {
        const empty = cloneEmptyState();
        empty.querySelector("p").textContent = "No n8n enriched fields detected yet. Extra top level JSON fields will appear here automatically.";
        elements.futureSections.replaceChildren(empty);
        return;
    }

    const cards = extraEntries.map(([key, value]) => renderObjectCard(key, value));
    elements.futureSections.replaceChildren(...cards);
}

function renderData() {
    const data = state.data;
    if (!data) {
        return;
    }

    elements.sourceLabel.textContent = state.sourceLabel;

    renderHeroMetrics(data);
    renderMacroCards(data);
    renderAlerts(data);
    renderStatusDetails(data);
    renderNutrients(data);
    renderFutureSections(data);
}

async function loadDefaultData() {
    try {
        setStatus("Loading default result JSON from logs.", "neutral");
        const response = await fetch(DEFAULT_DATA_PATH, { cache: "no-store" });
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}`);
        }

        const data = await response.json();
        state.data = data;
        state.sourceLabel = "Default result file";
        state.sourceKind = "default";
        setStatus("Loaded the current generated result file.", "good");
        renderData();
    } catch (error) {
        state.data = null;
        state.sourceLabel = "Waiting for data";
        elements.heroMetrics.replaceChildren();
        elements.macroCards.replaceChildren();
        elements.alertsList.replaceChildren(cloneEmptyState());
        elements.statusDetails.replaceChildren();
        elements.nutrientTableBody.replaceChildren();
        elements.futureSections.replaceChildren(cloneEmptyState());
        setStatus(`Default file load failed. ${error.message}. Use Open JSON or drag a file into the page.`, "warn");
    }
}

function loadFile(file) {
    const reader = new FileReader();

    reader.onload = () => {
        try {
            const data = JSON.parse(reader.result);
            state.data = data;
            state.sourceLabel = file.name;
            state.sourceKind = "uploaded";
            setStatus("Loaded JSON from the selected file.", "good");
            renderData();
        } catch (error) {
            setStatus(`That file is not valid JSON. ${error.message}`, "bad");
        }
    };

    reader.onerror = () => {
        setStatus("Could not read the selected file.", "bad");
    };

    reader.readAsText(file);
}

function handleDrop(event) {
    event.preventDefault();
    elements.dropZone.classList.remove("active");

    const [file] = event.dataTransfer.files;
    if (file) {
        loadFile(file);
    }
}

function parseCsv(text) {
    const lines = text.trim().split(/\r?\n/);
    if (lines.length < 2) return [];
    const headers = lines[0].split(",").map((h) => h.replace(/"/g, "").trim());
    return lines
        .slice(1)
        .filter((l) => l.trim())
        .map((line) => {
            const values = line.split(",").map((v) => v.replace(/"/g, "").trim());
            const row = {};
            headers.forEach((h, i) => { row[h] = values[i] ?? ""; });
            return row;
        });
}

function buildHistoryChart(rows, days) {
    const slice = rows.slice(-days);

    if (!slice.length) {
        return '<p class="muted chart-empty">No history yet. Run the extractor on a logged day to start building history.</p>';
    }

    const W = 900, H = 260;
    const PL = 46, PR = 16, PT = 16, PB = 44;
    const CW = W - PL - PR, CH = H - PT - PB;
    const n = slice.length;

    const xPos = (i) => PL + (n === 1 ? CW / 2 : (i / (n - 1)) * CW);
    const yPos = (pct) => PT + CH - (Math.max(0, Math.min(pct, 150)) / 150) * CH;

    const metrics = [
        { key: "CaloriesConsumed", goalKey: "CalorieGoal",     label: "Calories", color: "#b45227" },
        { key: "ProteinGrams",     goalKey: "ProteinGoalGrams", label: "Protein",  color: "#2b7a4b" }
    ];

    let svg = `<svg viewBox="0 0 ${W} ${H}" xmlns="http://www.w3.org/2000/svg" style="width:100%;display:block">`;

    for (const pct of [0, 25, 50, 75, 100, 125]) {
        const y = yPos(pct);
        const isGoal = pct === 100;
        svg += `<line x1="${PL}" y1="${y}" x2="${PL + CW}" y2="${y}"
            stroke="${isGoal ? "#b45227" : "rgba(29,26,23,0.09)"}"
            stroke-width="${isGoal ? 1.5 : 1}"
            ${isGoal ? 'stroke-dasharray="5,4"' : ""}/>`;
        svg += `<text x="${PL - 6}" y="${y + 4}" text-anchor="end" font-size="11" fill="#6b6258">${pct}%</text>`;
    }
    svg += `<text x="${PL + CW}" y="${yPos(100) - 5}" text-anchor="end" font-size="10" fill="#b45227">Goal</text>`;

    for (const metric of metrics) {
        const pcts = slice.map((row) => {
            const goal = parseFloat(row[metric.goalKey]);
            const val  = parseFloat(row[metric.key]);
            return goal > 0 && !isNaN(val) && !isNaN(goal) ? (val / goal) * 100 : null;
        });

        const pointStr = pcts
            .map((pct, i) => (pct !== null ? `${xPos(i)},${yPos(pct)}` : null))
            .filter(Boolean)
            .join(" ");

        if (pointStr) {
            svg += `<polyline points="${pointStr}" fill="none" stroke="${metric.color}"
                stroke-width="2.5" stroke-linejoin="round" stroke-linecap="round"/>`;
        }

        pcts.forEach((pct, i) => {
            if (pct !== null) {
                svg += `<circle cx="${xPos(i)}" cy="${yPos(pct)}" r="4"
                    fill="${metric.color}" stroke="#fff" stroke-width="1.5"/>`;
            }
        });
    }

    const labelEvery = n <= 10 ? 1 : Math.ceil(n / 10);
    slice.forEach((row, i) => {
        if (i % labelEvery === 0 || i === n - 1) {
            const label = row.DiaryDate || (row.RunDateTime || "").slice(5, 10);
            svg += `<text x="${xPos(i)}" y="${H - 6}" text-anchor="middle" font-size="11" fill="#6b6258">${label}</text>`;
        }
    });

    svg += "</svg>";
    return svg;
}

function renderHistoryChart() {
    elements.historyChart.innerHTML = buildHistoryChart(state.historyRows, state.historyDays);
}

async function loadHistoryData() {
    try {
        const response = await fetch(HISTORY_CSV_PATH, { cache: "no-store" });
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        const text = await response.text();
        state.historyRows = parseCsv(text);
        renderHistoryChart();
    } catch (error) {
        elements.historyChart.innerHTML = `<p class="muted chart-empty">History file not available yet. ${error.message}</p>`;
    }
}

elements.fileInput.addEventListener("change", (event) => {
    const [file] = event.target.files;
    if (file) {
        loadFile(file);
    }
});

elements.reloadDefaultButton.addEventListener("click", () => {
    loadDefaultData();
});

elements.nutrientSearch.addEventListener("input", () => {
    if (state.data) {
        renderNutrients(state.data);
    }
});

elements.targetModeSelect.addEventListener("change", () => {
    state.targetMode = elements.targetModeSelect.value;
    if (state.data) {
        renderNutrients(state.data);
    }
});

["dragenter", "dragover"].forEach((eventName) => {
    elements.dropZone.addEventListener(eventName, (event) => {
        event.preventDefault();
        elements.dropZone.classList.add("active");
    });
});

["dragleave", "drop"].forEach((eventName) => {
    elements.dropZone.addEventListener(eventName, (event) => {
        event.preventDefault();
        elements.dropZone.classList.remove("active");
    });
});

elements.dropZone.addEventListener("drop", handleDrop);

elements.dayToggleBtns.forEach((btn) => {
    btn.addEventListener("click", () => {
        elements.dayToggleBtns.forEach((b) => b.classList.remove("active"));
        btn.classList.add("active");
        state.historyDays = parseInt(btn.dataset.days, 10);
        renderHistoryChart();
    });
});

loadDefaultData();
loadHistoryData();
