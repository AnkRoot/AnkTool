# 史诗剧本：智慧沉淀

# 第一幕：形成判例
# 用户与“探案者”或“代码匠神”等模式交互，发现了一个深刻的教训。
# 用户现在启动这个工作流。

# 第二幕：向知识守卫提交草案
/mode lorekeeper
知识守卫，我们刚刚从以下事件中获得了一个深刻的教训：
{{lesson_learned_description}}
请将这个教训，提炼成一条简洁、准确、可执行的规则草案，准备写入我们的`02_tactical_playbook.md`。

# 第三幕：委托人确认
{{step_1_output}}
委托人，以上是知识守卫提炼出的规则草案。它是否准确地反映了代码库的真理，并且对我们未来的工作至关重要？(是/否)

# 第四幕：智慧铭刻
/mode lorekeeper
/if {{step_2_output}} == "是"
我已获得委托人的授权。现在，我将正式行使我的司法权力，将以下规则铭刻进`02_tactical_playbook.md`，并更新`99_changelog.md`：
{{step_1_output}}
/endif