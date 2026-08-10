const tokenRulesByLanguage = {
  bash: [
    { className: "syntax-comment", expression: /#[^\n]*/y },
    { className: "syntax-string", expression: /'(?:[^']*)'|"(?:\\.|[^"\\])*"/y },
    { className: "syntax-option", expression: /--?[A-Za-z][A-Za-z0-9-]*/y },
    { className: "syntax-command", expression: /(?:\.\/)?(?:Scripts\/ogkiln|Scripts\/build\.sh|Scripts\/quality_gate\.sh|script\/build_and_run\.sh)\b/y },
    { className: "syntax-keyword", expression: /\b(?:cd|git|clone|brew|install|node|true|false)\b/y },
    { className: "syntax-property", expression: /\$\{?[A-Za-z_][A-Za-z0-9_]*\}?/y },
    { className: "syntax-number", expression: /\b\d+(?:\.\d+)?(?:px|rem|s|ms)?\b/y }
  ],
  json: [
    { className: "syntax-property", expression: /"(?:\\.|[^"\\])*"(?=\s*:)/y },
    { className: "syntax-string", expression: /"(?:\\.|[^"\\])*"/y },
    { className: "syntax-keyword", expression: /\b(?:true|false|null)\b/y },
    { className: "syntax-number", expression: /-?\b\d+(?:\.\d+)?(?:[eE][+-]?\d+)?\b/y },
    { className: "syntax-punctuation", expression: /[{}\[\],:]/y }
  ],
  html: [
    { className: "syntax-comment", expression: /<!--[\s\S]*?-->/y },
    { className: "syntax-tag", expression: /<\/?[A-Za-z][A-Za-z0-9-]*/y },
    { className: "syntax-attribute", expression: /\b[A-Za-z_:][A-Za-z0-9_:.-]*(?=\s*=)/y },
    { className: "syntax-string", expression: /"(?:&[A-Za-z0-9#]+;|[^"])*"|'(?:&[A-Za-z0-9#]+;|[^'])*'/y },
    { className: "syntax-punctuation", expression: /\/?\s*>|=/y }
  ]
};

function highlightedFragment(source, language) {
  const fragment = document.createDocumentFragment();
  const rules = tokenRulesByLanguage[language] || [];
  let index = 0;

  while (index < source.length) {
    let match = null;
    let className = "";

    for (const rule of rules) {
      rule.expression.lastIndex = index;
      const candidate = rule.expression.exec(source);
      if (candidate && candidate.index === index) {
        match = candidate[0];
        className = rule.className;
        break;
      }
    }

    if (!match) {
      fragment.append(document.createTextNode(source[index]));
      index += 1;
      continue;
    }

    const token = document.createElement("span");
    token.className = className;
    token.textContent = match;
    fragment.append(token);
    index += match.length;
  }

  return fragment;
}

function highlightCodeBlocks() {
  document.querySelectorAll("pre code[data-language]").forEach((code) => {
    const source = code.textContent || "";
    code.replaceChildren(highlightedFragment(source, code.dataset.language || ""));
  });
}

document.addEventListener("DOMContentLoaded", () => {
  highlightCodeBlocks();
});
