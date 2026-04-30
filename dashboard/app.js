const DEFAULT_DATA_PATH = "../logs/CronometerMonitorResult.json";

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
    sourceKind: "none"
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
    futureSections: document.getElementById("futureSections"),
    fileInput: document.getElementById("fileInput"),
    reloadDefaultButton: document.getElementById("reloadDefaultButton"),
    dropZone: document.getElementById("dropZone"),
    emptyStateTemplate: document.getElementById("emptyStateTemplate")
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

function renderNutrients(data) {
    const filter = elements.nutrientSearch.value.trim().toLowerCase();
    const nutrients = Array.isArray(data.Nutrients) ? data.Nutrients : [];
    const filtered = nutrients.filter((item) => {
        const haystack = `${item.Name ?? ""} ${item.Unit ?? ""}`.toLowerCase();
        return !filter || haystack.includes(filter);
    });

    if (!filtered.length) {
        const row = document.createElement("tr");
        row.innerHTML = `<td colspan="3">No nutrient rows match the current filter.</td>`;
        elements.nutrientTableBody.replaceChildren(row);
        return;
    }

    const rows = filtered.map((nutrient) => {
        const row = document.createElement("tr");
        row.innerHTML = `
            <td>${formatValue(nutrient.Name)}</td>
            <td>${formatValue(nutrient.Value)}</td>
            <td>${formatValue(nutrient.Unit)}</td>
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

loadDefaultData();
