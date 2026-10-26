(() => {
  const links = [
    { href: "/", label: "Guarda" },
    { href: "/upload.html", label: "Gestione" },
    { href: "/docs", label: "API", external: true },
  ];

  const header = document.createElement("header");
  header.className = "topbar";
  header.innerHTML = `<a class="brand" href="/"><span class="dot"></span>StreamTube</a><nav></nav>`;
  const nav = header.querySelector("nav");

  for (const l of links) {
    const a = document.createElement("a");
    a.href = l.href;
    a.textContent = l.label;
    if (l.external) a.target = "_blank";
    else if (location.pathname === l.href) a.classList.add("current");
    nav.append(a);
  }
  document.body.prepend(header);

  const box = document.createElement("div");
  box.className = "toasts";
  document.body.append(box);

  // Notifica temporanea: window.toast("testo", "ok" | "err" | "")
  window.toast = (text, kind = "") => {
    const t = document.createElement("div");
    t.className = `toast ${kind}`;
    t.textContent = text;
    box.append(t);
    setTimeout(() => t.remove(), 4000);
  };
})();