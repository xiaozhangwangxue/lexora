"use client";

import Image from "next/image";
import Link from "next/link";
import { useSiteLanguage } from "../use-site-language";

const qrBase = "https://raw.githubusercontent.com/xiaozhangwangxue/autoword/main/assets/donate";

export default function DonatePage() {
  const { language, setLanguage, zh } = useSiteLanguage();
  return (
    <main className="donatePage">
      <nav className="nav wrap" aria-label={zh ? "捐款页面导航" : "Donation navigation"}>
        <Link className="brand" href="/">
          <img src="/lexora-icon-192.png" alt="" width="36" height="36" />
          <span>Lexora</span>
        </Link>
        <div className="donateNavActions">
          <button className="language" onClick={() => setLanguage(language === "zh" ? "en" : "zh")}>
            {zh ? "EN" : "中文"}
          </button>
          <Link className="donateBack" href="/">{zh ? "← 返回首页" : "← Back to Lexora"}</Link>
        </div>
      </nav>

      <section className="donateHero wrap">
        <div className="donateHeart">♥</div>
        <p className="sectionLabel">{zh ? "支持独立开发" : "Support independent development"}</p>
        <h1>{zh ? <>让好单词，<br /><em>走得更远。</em></> : <>Help good words<br /><em>travel further.</em></>}</h1>
        <p>{zh
          ? "Lexora 免费使用，并由个人持续维护。你的自愿支持将用于跨平台测试、应用签名、数据服务和长期更新。"
          : "Lexora is free to use and built with care. Your voluntary support helps cover cross-platform testing, code signing, data services, and long-term maintenance."}
        </p>
      </section>

      <section className="qrGrid wrap">
        <article>
          <div className="qrHeading"><span className="wechatDot">微</span><div><h2>微信支付</h2><p>WeChat Pay</p></div></div>
          <div className="qrFrame">
            <Image src={`${qrBase}/wechat.png`} alt="微信支付收款码" width={620} height={620} unoptimized />
          </div>
          <p>{zh ? "打开微信扫一扫" : "Scan with WeChat"}</p>
        </article>
        <article>
          <div className="qrHeading"><span className="alipayDot">支</span><div><h2>支付宝</h2><p>Alipay</p></div></div>
          <div className="qrFrame">
            <Image src={`${qrBase}/alipay.jpg`} alt="支付宝收款码" width={620} height={620} unoptimized />
          </div>
          <p>{zh ? "打开支付宝扫一扫" : "Scan with Alipay"}</p>
        </article>
      </section>

      <section className="donateNote wrap">
        <div>
          <strong>{zh ? "谢谢你的认可。" : "Thank you for your support."}</strong>
          <p>{zh
            ? "捐款完全自愿，不会解锁额外付费功能；Lexora 会继续保持免费使用。"
            : "Donations are entirely optional and do not unlock paid features. Lexora remains free to use."}
          </p>
        </div>
        <Link href="/">{zh ? "继续使用 Lexora →" : "Continue to Lexora →"}</Link>
      </section>
    </main>
  );
}
