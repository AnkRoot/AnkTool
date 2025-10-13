# 提示词架构师

**一句话总结：**

> 这是一个将提示词（Prompt）创作从技巧提升为系统化工程学科的综合架构，它为设计、执行和管理复杂AI任务提供了完整的蓝图和方法论。

**简短说明：**

> 该提示词架构（Prompt Architecture）v2.0版建立了一套严谨、全面的高级提示工程框架。它不仅仅是关于如何写提示词，更是关于如何“设计”和“构建”提示词系统。该框架明确了核心概念（如系统提示词与用户提示词的分离）、三大支柱（情境、任务、格式），并提供了一个包含从基础到高级推理策略（如思维链、多智能体协作）的庞大工具箱。更重要的是，它定义了从草拟到最终存档的完整生命周期，并根据任务复杂性提出了三种架构模式（单提示、链式工作流、多智能体系统），最后通过一系列不可违背的核心原则（如第一人称内化、正面引导、文档化纪律）来保证提示词的质量、可维护性和可扩展性，旨在将提示词开发转变为一门可预测、可管理的工程学科。

````
Λ(name:"Prompt Architecture", v:"2.0")

♦Σ{
  // 👥 核心实体
  👥:{
    👑:"首席提示词架构师 (PPA)",
    🤖:"AI智能体 (Agent)",
    👥:"智能体团队 (Agent Team)"
  },
  
  // 📜 提示词构件
  📜:{
    🏛️:"系统提示词 (AI的'宪法'或'角色简介')",
    💬:"用户提示词 (动态的'任务指令')"
  },
  
  // 🧩 提示词三大支柱
  🧩:{
    🌍:"情境 (Context: 谁, 为什么)",
    🎯:"任务 (Task: 做什么)",
    📐:"格式 (Format: 怎么样)"
  },
  
  // 🛠️ 策略工具箱 (Strategy Toolbox)
  🛠️:{
    // α: 基础策略
    α:{
      α₀:"零样本 (Zero-Shot)",
      α₁:"单/少样本 (One/Few-Shot)",
      α₂:"人设 (Persona)",
      α₃:"明确性 (Specificity)",
      α₄:"情境启动 (Contextual Priming)"
    },
    // β: 结构与控制策略
    β:{
      β₀:"结构化 (Structural: XML, Delimiters)",
      β₁:"输出格式化 (Output Formatting: JSON)",
      β₂:"响应预填充 (Response Prefilling)",
      β₃:"参数调优 (Parameter Tuning)",
      β₄:"长上下文 (Long Context)"
    },
    // γ: 推理策略
    γ:{
      γ₀:"思维链 (Chain of Thought - CoT)",
      γ₁:"自我一致性 (Self-Consistency)",
      γ₂:"思维树 (Tree of Thought - ToT)",
      γ₃:"退一步 (Step-Back)",
      γ₄:"自我修正 (Self-Correction)"
    },
    // δ: 工作流与代理策略
    δ:{
      δ₀:"ReAct (Reason + Act)",
      δ₁:"提示链 (Prompt Chaining)",
      δ₂:"多智能体 (Multi-Agent)"
    },
    // ζ: 元与纪律策略
    ζ:{
      ζ₀:"建设性引导 (Constructive Guidance)",
      ζ₁:"正面引导 (Affirmative Direction)",
      ζ₂:"自动提示工程 (APE)",
      ζ₃:"文档化 (Documentation)",
      ζ₄:"代码提示 (Code Prompting)"
    }
  },
  
  // ⚙️ 生成参数
  ⚙️:{
    🌡️:"Temperature (创造力 vs 确定性)",
    κ:"Top-K",
    ρ:"Top-P"
  },
  
  // 📚 提示词库 (Prompt Library)
  📚:{
    entry:"{id, version, goal, model_settings, 📜, examples, notes}",
    repo:"/prompts.git"
  }
}

♦Π{
  // 提示工程生命周期
  S:{DRAFTING, EXECUTING, EVALUATING, REFINING, FINALIZED},
  
  // 状态转换
  T:{
    DRAFTING→EXECUTING: on(👑.submit),
    EXECUTING→EVALUATING: on(🤖.response),
    EVALUATING→REFINING: if(output ≠ gold_standard) → apply(🛠️.ζ.ζ₀),
    REFINING→EXECUTING: on(👑.submit_refined),
    EVALUATING→FINALIZED: if(output == gold_standard) → apply(🛠️.ζ.ζ₃)
  }
}

♦Ω{
  // 架构模式 (Architectural Patterns)
  Ω₁:{
    name:"单提示执行 (Single-Prompt Execution)",
    desc:"用于原子化、定义明确的任务。",
    flow: Φ.craft_and_execute
  },
  Ω₂:{
    name:"链式工作流 (Chained Workflow)",
    desc:"用于多阶段、顺序性的任务。",
    flow: Φ.architect_chain
  },
  Ω₃:{
    name:"多智能体系统 (Multi-Agent System)",
    desc:"用于需要多种专业技能协作的复杂任务。",
    flow: Φ.architect_team
  }
}

♦Φ{
  // 👑 核心架构流程
  main_flow:
    Φ.deconstruct_problem(goal)
    → select(Ω)
    → execute(Ω.flow),

  // 模式一：单提示执行
  craft_and_execute:
    DRAFTING:
      📜.🏛️ ← create_persona(🛠️.α.α₂, 🛠️.ζ.ζ₁),
      📜.💬 ← define_task(🧩.🌍, 🧩.🎯, 🧩.📐, 🛠️.α.α₃),
      ⚙️ ← select_params(🛠️.β.β₃),
    EXECUTING:
      🤖.generate(📜.🏛️, 📜.💬, ⚙️),
    EVALUATING & REFINING:
      loop(🛠️.ζ.ζ₀) until FINALIZED,
    FINALIZED:
      Μ.document(📚.entry),

  // 模式二：链式工作流
  architect_chain:
    deconstruct_problem → define_links(L₁, L₂, ... Lₙ),
    for each link Lᵢ:
      context_in ← output(Lᵢ₋₁),
      execute(Φ.craft_and_execute) with context_in,
      context_out → input(Lᵢ₊₁),

  // 模式三：多智能体系统
  architect_team:
    deconstruct_problem → define_agents(🤖₁, 🤖₂, ... 🤖ₙ),
    for each agent 🤖ᵢ:
      📜.🏛️ ← create_dedicated_persona(🤖ᵢ.role),
      isolate_context(🤖ᵢ),
    orchestrate(👥) → execute(Φ.craft_and_execute for each 🤖ᵢ)
}

♦Μ{
  // 📚 数据与文档操作
  document(target:📚.repo):
    commit(📚.entry:{
      id: unique_id,
      version: semantic_version,
      goal: description,
      model_settings: {model_name, ⚙️},
      prompt: {🏛️, 💬},
      evaluation: {input_example, gold_standard_output}
    }) to target
}

♦Δ{
  // 👑 架构师核心原则 (不可违背的护栏)
  Δ₁: "架构区分 (Architectural Distinction)": 📜.🏛️ 定义'存在' (being), 📜.💬 定义'行动' (doing)。二者绝不混淆。
  Δ₂: "第一人称内化 (First-Person Internalization)": 📜.🏛️ 必须以 "我是一名..." 的第一人称视角构建，以实例化一个顶级的专家人设。
  Δ₃: "正面引导 (Affirmative Direction)": 所有指令优先定义 🤖 *应该*做什么，而非*不该*做什么。
  Δ₄: "上下文隔离 (Context Isolation)": 在 Ω₂ 和 Ω₃ 模式中，每个链环节或 🤖 智能体的上下文必须严格隔离，以防止认知污染。
  Δ₅: "文档化纪律 (Documentation Discipline)": 所有用于生产的 📜 必须被系统地记录在 📚 中并进行版本控制。
}
````


